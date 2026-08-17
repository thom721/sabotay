from datetime import timedelta
from decimal import Decimal

from sqlalchemy import func
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select

import app.crud.transaction as crud_transaction
from app.models.client import Client
from app.models.compte_sabotay import CompteSabotay
from app.schemas.compte_sabotay import CompteSabotayAvecSolde, CompteSabotayCreate

_MAX_TENTATIVES_NUMERO = 5


async def _prochain_rang(session: AsyncSession, *, entreprise_id: str) -> int:
    # MAX(rang) plutôt que COUNT(*) : un compte supprimé ne fait pas régresser
    # le rang, ce qui éviterait de régénérer un numéro déjà attribué.
    result = await session.execute(
        select(func.max(CompteSabotay.numero_compte)).where(
            CompteSabotay.entreprise_id == entreprise_id
        )
    )
    dernier_numero = result.scalar_one_or_none()
    if dernier_numero is None:
        return 1
    return int(dernier_numero.removeprefix("SB-")) + 1


async def create(
    session: AsyncSession, *, entreprise_id: str, data: CompteSabotayCreate
) -> CompteSabotay:
    date_fin_prevue = data.date_debut + timedelta(days=data.duree_jours)
    montant_total_attendu = data.montant_journalier * Decimal(data.duree_jours)

    rang = await _prochain_rang(session, entreprise_id=entreprise_id)
    for tentative in range(_MAX_TENTATIVES_NUMERO):
        compte = CompteSabotay(
            entreprise_id=entreprise_id,
            client_id=data.client_id,
            numero_compte=f"SB-{rang:06d}",
            montant_journalier=data.montant_journalier,
            date_debut=data.date_debut,
            duree_jours=data.duree_jours,
            date_fin_prevue=date_fin_prevue,
            montant_total_attendu=montant_total_attendu,
        )
        session.add(compte)
        try:
            await session.commit()
        except IntegrityError:
            # Numéro pris entre-temps par une création concurrente : on
            # retente avec le rang suivant plutôt que de laisser échouer
            # la requête (cause directe d'erreurs de saisie côté agent).
            await session.rollback()
            if tentative == _MAX_TENTATIVES_NUMERO - 1:
                raise
            rang += 1
            continue
        await session.refresh(compte)
        return compte

    raise AssertionError("unreachable")


async def get_for_tenant(
    session: AsyncSession, *, compte_id: str, entreprise_id: str
) -> CompteSabotay | None:
    statement = select(CompteSabotay).where(
        CompteSabotay.id == compte_id, CompteSabotay.entreprise_id == entreprise_id
    )
    result = await session.execute(statement)
    return result.scalar_one_or_none()


async def get_by_numero(
    session: AsyncSession, *, numero_compte: str, entreprise_id: str
) -> CompteSabotay | None:
    statement = select(CompteSabotay).where(
        CompteSabotay.numero_compte == numero_compte,
        CompteSabotay.entreprise_id == entreprise_id,
    )
    result = await session.execute(statement)
    return result.scalar_one_or_none()


async def list_for_client(
    session: AsyncSession, *, client_id: str, entreprise_id: str
) -> list[CompteSabotay]:
    statement = select(CompteSabotay).where(
        CompteSabotay.client_id == client_id,
        CompteSabotay.entreprise_id == entreprise_id,
    )
    result = await session.execute(statement)
    return list(result.scalars().all())


async def list_for_tenant_avec_soldes(
    session: AsyncSession,
    *,
    entreprise_id: str,
    agent_id: str | None = None,
    skip: int = 0,
    limit: int = 200,
) -> tuple[list[CompteSabotayAvecSolde], int]:
    """Comptes du tenant avec solde calculé en une seule requête groupée
    (voir `crud/transaction.py::get_soldes_bulk`) plutôt qu'un aller-retour
    par compte — pour le cache offline mobile (Epic 6) et tout futur écran
    listant plusieurs comptes. `agent_id` restreint aux comptes des clients
    assignés à cet agent (mêmes règles que `crud/client.py::list_for_tenant`)."""
    base = select(CompteSabotay).where(CompteSabotay.entreprise_id == entreprise_id)
    if agent_id is not None:
        base = base.join(Client, Client.id == CompteSabotay.client_id).where(
            Client.agent_assigne_id == agent_id
        )

    total = (
        await session.execute(select(func.count()).select_from(base.subquery()))
    ).scalar_one()

    statement = base.order_by(CompteSabotay.numero_compte).offset(skip).limit(limit)
    comptes = list((await session.execute(statement)).scalars().all())
    if not comptes:
        return [], total

    soldes = await crud_transaction.get_soldes_bulk(
        session, compte_ids=[c.id for c in comptes]
    )

    resultats = []
    for compte in comptes:
        montant_collecte, montant_retire, jours_payes = soldes.get(
            compte.id, (Decimal("0"), Decimal("0"), 0)
        )
        resultats.append(
            CompteSabotayAvecSolde(
                **compte.model_dump(),
                **crud_transaction.calculer_champs_solde(
                    compte, montant_collecte, montant_retire, jours_payes
                ),
            )
        )
    return resultats, total


async def get_for_client(
    session: AsyncSession, *, compte_id: str, client_id: str, entreprise_id: str
) -> CompteSabotay | None:
    """Vérifie qu'un compte appartient bien au client authentifié avant de
    lui exposer son solde/historique (portail libre-service, PRD §8.8)."""
    statement = select(CompteSabotay).where(
        CompteSabotay.id == compte_id,
        CompteSabotay.client_id == client_id,
        CompteSabotay.entreprise_id == entreprise_id,
    )
    result = await session.execute(statement)
    return result.scalar_one_or_none()
