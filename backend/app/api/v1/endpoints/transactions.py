from datetime import date, timedelta
from decimal import Decimal
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import select

import app.crud.compte_sabotay as crud_compte
import app.crud.platform_config as crud_platform_config
import app.crud.transaction as crud_transaction
from app.core import licence
from app.core.config import settings
from app.core.db import get_session
from app.core.deps import CurrentUser, TenantId, require_roles
from app.core.dt_utils import now_local
from app.models.abonnement import Abonnement, StatutAbonnement
from app.models.entreprise import Entreprise
from app.models.transaction import TypeTransaction
from app.models.utilisateur import RoleUtilisateur
from app.schemas.transaction import (
    RapportRead,
    RetraitCreate,
    TransactionCreate,
    TransactionRead,
    TransactionRegistreItem,
    TransactionRegistrePage,
)
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(tags=["transactions"])

SessionDep = Annotated[AsyncSession, Depends(get_session)]

_ROLES_COLLECTE = Depends(
    require_roles(RoleUtilisateur.ADMIN, RoleUtilisateur.MANAGER, RoleUtilisateur.AGENT)
)


async def _abonnement_actif(session: SessionDep, entreprise_id: str) -> bool:
    """Vérifie que l'abonnement du tenant est ACTIF et non expiré, ou que
    l'entreprise est encore dans sa période d'essai gratuit configurable
    (PRD §8.5, `platform_config.essai_jours`, décomptée depuis
    `Entreprise.date_creation`). La collecte de cotisations (POST
    /transactions) est bloquée sinon, alors que la création de
    clients/employés/comptes reste libre (PRD paiement MonCash).

    En mode local, `abonnements` n'est jamais synchronisé (voir `ENTITES`
    dans sync.py) — la requête ci-dessous ne trouverait donc jamais rien et
    bloquerait la collecte en permanence sur un poste bureau. On consulte à
    la place le cache de licence Ed25519 vérifié (voir
    `core/licence.py::abonnement_actif_local`), jamais d'appel réseau ici."""
    if settings.LOCAL_MODE:
        return await licence.abonnement_actif_local(session)

    result = await session.execute(
        select(Abonnement).where(Abonnement.entreprise_id == entreprise_id)
    )
    abonnement = result.scalar_one_or_none()
    if abonnement is None:
        return False
    if abonnement.statut == StatutAbonnement.ESSAI:
        entreprise = await session.get(Entreprise, entreprise_id)
        essai_jours = (await crud_platform_config.get(session)).essai_jours
        limite_essai = entreprise.date_creation + timedelta(days=essai_jours)
        return now_local() <= limite_essai
    if abonnement.statut != StatutAbonnement.ACTIF:
        return False
    if abonnement.date_renouvellement is None:
        return True
    return abonnement.date_renouvellement >= now_local().date()


@router.post(
    "/transactions",
    response_model=TransactionRead,
    status_code=status.HTTP_201_CREATED,
    dependencies=[_ROLES_COLLECTE],
)
async def create_transaction(
    payload: TransactionCreate,
    session: SessionDep,
    entreprise_id: TenantId,
    current_user: CurrentUser,
) -> TransactionRead:
    if not await _abonnement_actif(session, entreprise_id):
        montant = (await crud_platform_config.get(session)).abonnement_montant_htg
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail=(
                "Abonnement requis pour enregistrer des cotisations. "
                f"Veuillez régler votre abonnement annuel ({montant} HTG)."
            ),
        )

    compte = await crud_compte.get_for_tenant(
        session, compte_id=payload.compte_id, entreprise_id=entreprise_id
    )
    if compte is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Compte introuvable")

    transaction = await crud_transaction.create(
        session,
        entreprise_id=entreprise_id,
        collecte_par_id=current_user.id,
        collecte_par_nom=current_user.nom,
        data=payload,
        compte=compte,
    )
    return transaction


@router.post(
    "/transactions/retrait",
    response_model=TransactionRead,
    status_code=status.HTTP_201_CREATED,
    dependencies=[_ROLES_COLLECTE],
)
async def create_retrait(
    payload: RetraitCreate,
    session: SessionDep,
    entreprise_id: TenantId,
    current_user: CurrentUser,
) -> TransactionRead:
    """Retrait partiel, possible à tout moment — pas de blocage abonnement :
    rendre l'argent du client doit toujours fonctionner, contrairement à
    l'enregistrement de nouvelles cotisations."""
    compte = await crud_compte.get_for_tenant(
        session, compte_id=payload.compte_id, entreprise_id=entreprise_id
    )
    if compte is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Compte introuvable")

    entreprise = await session.get(Entreprise, entreprise_id)
    if entreprise is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Entreprise introuvable")

    try:
        transaction = await crud_transaction.create_retrait(
            session,
            entreprise_id=entreprise_id,
            collecte_par_id=current_user.id,
            collecte_par_nom=current_user.nom,
            data=payload,
            compte=compte,
            frais_retrait=entreprise.frais_retrait,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error)) from error

    return transaction


@router.get("/comptes/{compte_id}/transactions", response_model=list[TransactionRead])
async def list_transactions_for_compte(
    compte_id: str, session: SessionDep, entreprise_id: TenantId
) -> list[TransactionRead]:
    compte = await crud_compte.get_for_tenant(
        session, compte_id=compte_id, entreprise_id=entreprise_id
    )
    if compte is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Compte introuvable")
    return await crud_transaction.list_for_compte(session, compte_id=compte_id)


@router.get(
    "/transactions/rapport",
    response_model=RapportRead,
    dependencies=[_ROLES_COLLECTE],
)
async def read_rapport_transactions(
    date_debut: date,
    date_fin: date,
    session: SessionDep,
    entreprise_id: TenantId,
    current_user: CurrentUser,
    agent_id: str | None = None,
) -> RapportRead:
    """Rapport de collecte imprimable sur une période (PRD §8.7) — un Agent
    est forcé sur ses propres collectes (même si `agent_id` est fourni, pour
    ne jamais lui permettre de consulter les collectes d'un autre agent).
    Admin/Manager voient tout le tenant par défaut, ou un agent précis via
    `agent_id` (filtre côté web, PRD Rapports)."""
    if date_fin < date_debut:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="La date de fin doit être postérieure à la date de début",
        )

    collecte_par_id = (
        current_user.id if current_user.role == RoleUtilisateur.AGENT else agent_id
    )
    transactions = await crud_transaction.list_for_periode(
        session,
        entreprise_id=entreprise_id,
        date_debut=date_debut,
        date_fin=date_fin,
        collecte_par_id=collecte_par_id,
    )

    total_collecte = sum(
        (t.montant for t in transactions if t.type == TypeTransaction.COLLECTE),
        Decimal("0"),
    )
    total_retrait = sum(
        (t.montant for t in transactions if t.type == TypeTransaction.RETRAIT),
        Decimal("0"),
    )

    return RapportRead(
        date_debut=date_debut,
        date_fin=date_fin,
        total_collecte=total_collecte,
        total_retrait=total_retrait,
        nb_transactions=len(transactions),
        transactions=transactions,
    )


@router.get(
    "/transactions",
    response_model=TransactionRegistrePage,
    dependencies=[_ROLES_COLLECTE],
)
async def read_registre_transactions(
    session: SessionDep,
    entreprise_id: TenantId,
    current_user: CurrentUser,
    q: str | None = None,
    skip: int = 0,
    limit: int = 50,
) -> TransactionRegistrePage:
    """Registre brut, paginé, recherche libre par client/compte/agent — pour
    retrouver une transaction précise, contrairement à `/transactions/rapport`
    qui sert un rapport de synthèse borné à une période. Un Agent est forcé
    sur ses propres collectes, comme le rapport."""
    limit = min(limit, 200)
    collecte_par_id = current_user.id if current_user.role == RoleUtilisateur.AGENT else None

    rows, total = await crud_transaction.list_registre(
        session,
        entreprise_id=entreprise_id,
        q=q,
        collecte_par_id=collecte_par_id,
        skip=skip,
        limit=limit,
    )

    items = [
        TransactionRegistreItem(
            **transaction.model_dump(),
            client_nom=f"{prenom} {nom}".strip(),
            compte_numero=compte_numero,
        )
        for transaction, prenom, nom, compte_numero in rows
    ]
    return TransactionRegistrePage(items=items, total=total)
