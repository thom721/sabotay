from datetime import timedelta
from decimal import Decimal
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select

import app.crud.platform_config as crud_platform_config
from app.core.db import get_session
from app.core.deps import CurrentSuperAdmin
from app.core.dt_utils import now_local
from app.core.security import hash_password
from app.models.abonnement import Abonnement, StatutAbonnement
from app.models.client import Client
from app.models.code_installation import CodeInstallation, generer_code_installation
from app.models.entreprise import Entreprise
from app.models.paiement_abonnement import PaiementAbonnement
from app.models.super_admin import SuperAdmin
from app.models.transaction import Transaction, TypeTransaction
from app.models.utilisateur import Utilisateur
from app.schemas.abonnement import PaiementAbonnementRead, PaiementEnAttenteRead
from app.schemas.superadmin import (
    AbonnementSuperAdminRead,
    ClientSuperAdminRead,
    EntrepriseSuperAdminDetailRead,
    EntrepriseSuperAdminRead,
    PlatformConfigRead,
    PlatformConfigUpdate,
    StatistiquesSuperAdminRead,
    SuperAdminCompteCreate,
    SuperAdminCompteRead,
    SuperAdminStatutUpdate,
    UtilisateurSuperAdminRead,
)

router = APIRouter(prefix="/superadmin", tags=["superadmin"])

SessionDep = Annotated[AsyncSession, Depends(get_session)]


async def _build_entreprise_summary(
    session: AsyncSession, entreprise: Entreprise
) -> EntrepriseSuperAdminRead:
    abonnement_result = await session.execute(
        select(Abonnement).where(Abonnement.entreprise_id == entreprise.id)
    )
    abonnement = abonnement_result.scalar_one_or_none()

    nb_employes_result = await session.execute(
        select(func.count()).select_from(Utilisateur).where(
            Utilisateur.entreprise_id == entreprise.id
        )
    )
    nb_employes = nb_employes_result.scalar_one()

    nb_clients_result = await session.execute(
        select(func.count()).select_from(Client).where(
            Client.entreprise_id == entreprise.id
        )
    )
    nb_clients = nb_clients_result.scalar_one()

    return EntrepriseSuperAdminRead(
        id=entreprise.id,
        nom=entreprise.nom,
        devise=entreprise.devise,
        statut=entreprise.statut,
        date_creation=entreprise.date_creation,
        abonnement=(
            AbonnementSuperAdminRead(
                plan=abonnement.plan,
                statut=abonnement.statut,
                date_renouvellement=abonnement.date_renouvellement,
                montant=abonnement.montant,
            )
            if abonnement is not None
            else None
        ),
        nb_employes=nb_employes,
        nb_clients=nb_clients,
        est_installe=entreprise.est_installe,
    )


@router.get("/entreprises", response_model=list[EntrepriseSuperAdminRead])
async def list_all_entreprises(
    session: SessionDep,
    current_super_admin: CurrentSuperAdmin,
    q: str | None = None,
    statut_abonnement: str | None = None,
) -> list[EntrepriseSuperAdminRead]:
    """Vue plateforme : toutes les entreprises tous tenants confondus (pas de filtre tenant).

    `q` : sous-chaîne insensible à la casse sur le nom de l'entreprise.
    `statut_abonnement` : filtre exact sur le statut de l'abonnement lié ; les
    entreprises sans abonnement sont exclues si ce filtre est utilisé.
    """
    statement = select(Entreprise)
    if statut_abonnement is not None:
        statement = statement.join(
            Abonnement, Abonnement.entreprise_id == Entreprise.id
        ).where(Abonnement.statut == statut_abonnement)
    if q is not None:
        statement = statement.where(Entreprise.nom.ilike(f"%{q}%"))

    result = await session.execute(statement)
    entreprises = result.scalars().all()
    return [await _build_entreprise_summary(session, entreprise) for entreprise in entreprises]


@router.get("/statistiques", response_model=StatistiquesSuperAdminRead)
async def read_statistiques(
    session: SessionDep, current_super_admin: CurrentSuperAdmin
) -> StatistiquesSuperAdminRead:
    """Agrégats plateforme tous tenants confondus (requêtes SQL agrégées, pas de comptage Python)."""
    nb_entreprises_total = (
        await session.execute(select(func.count()).select_from(Entreprise))
    ).scalar_one()

    nb_entreprises_abonnement_actif = (
        await session.execute(
            select(func.count())
            .select_from(Abonnement)
            .where(Abonnement.statut == StatutAbonnement.ACTIF)
        )
    ).scalar_one()

    nb_clients_total = (
        await session.execute(select(func.count()).select_from(Client))
    ).scalar_one()

    nb_employes_total = (
        await session.execute(select(func.count()).select_from(Utilisateur))
    ).scalar_one()

    montant_total_collecte = (
        await session.execute(
            select(func.coalesce(func.sum(Transaction.montant), 0)).where(
                Transaction.type == TypeTransaction.COLLECTE
            )
        )
    ).scalar_one()

    montant_abonnements_collecte = (
        await session.execute(
            select(func.coalesce(func.sum(Abonnement.montant), 0)).where(
                Abonnement.statut == StatutAbonnement.ACTIF
            )
        )
    ).scalar_one()

    return StatistiquesSuperAdminRead(
        nb_entreprises_total=nb_entreprises_total,
        nb_entreprises_abonnement_actif=nb_entreprises_abonnement_actif,
        nb_clients_total=nb_clients_total,
        nb_employes_total=nb_employes_total,
        montant_total_collecte=Decimal(montant_total_collecte),
        montant_abonnements_collecte=montant_abonnements_collecte,
    )


def _to_platform_config_read(config) -> PlatformConfigRead:
    return PlatformConfigRead(
        abonnement_montant_htg=config.abonnement_montant_htg,
        abonnement_renouvellement_htg=config.abonnement_renouvellement_htg,
        essai_jours=config.essai_jours,
        smtp_host=config.smtp_host,
        smtp_port=config.smtp_port,
        smtp_user=config.smtp_user,
        smtp_password_defini=bool(config.smtp_password),
        smtp_from_email=config.smtp_from_email,
    )


@router.get("/config", response_model=PlatformConfigRead)
async def read_platform_config(
    session: SessionDep, current_super_admin: CurrentSuperAdmin
) -> PlatformConfigRead:
    """Réglages globaux de la plateforme : abonnement (prix, essai) et email
    SMTP dynamique (Paramètres → Email) — jamais le mot de passe SMTP réel,
    seulement s'il est défini."""
    config = await crud_platform_config.get(session)
    return _to_platform_config_read(config)


@router.patch("/config", response_model=PlatformConfigRead)
async def update_platform_config(
    payload: PlatformConfigUpdate,
    session: SessionDep,
    current_super_admin: CurrentSuperAdmin,
) -> PlatformConfigRead:
    if payload.abonnement_montant_htg is not None and payload.abonnement_montant_htg <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Le montant doit être positif"
        )
    if (
        payload.abonnement_renouvellement_htg is not None
        and payload.abonnement_renouvellement_htg <= 0
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le prix de renouvellement doit être positif",
        )
    if payload.essai_jours is not None and payload.essai_jours <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le nombre de jours d'essai doit être positif",
        )
    config = await crud_platform_config.update(session, payload)
    return _to_platform_config_read(config)


@router.get("/comptes", response_model=list[SuperAdminCompteRead])
async def list_comptes_super_admin(
    session: SessionDep, current_super_admin: CurrentSuperAdmin
) -> list[SuperAdminCompteRead]:
    """Liste des comptes super-admin de la plateforme (jamais le hash du mot de passe)."""
    result = await session.execute(select(SuperAdmin))
    return [
        SuperAdminCompteRead(
            id=sa.id,
            nom=sa.nom,
            email=sa.email,
            statut=sa.statut,
            date_creation=sa.date_creation,
            derniere_connexion=sa.derniere_connexion,
        )
        for sa in result.scalars().all()
    ]


@router.post(
    "/comptes",
    response_model=SuperAdminCompteRead,
    status_code=status.HTTP_201_CREATED,
)
async def create_compte_super_admin(
    payload: SuperAdminCompteCreate,
    session: SessionDep,
    current_super_admin: CurrentSuperAdmin,
) -> SuperAdminCompteRead:
    """Créer un nouveau compte super-admin plateforme."""
    existing_result = await session.execute(
        select(SuperAdmin).where(SuperAdmin.email == payload.email)
    )
    if existing_result.scalar_one_or_none() is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Un compte super-admin existe déjà avec cet email",
        )

    super_admin = SuperAdmin(
        nom=payload.nom,
        email=payload.email,
        hashed_password=hash_password(payload.password),
        statut="actif",
    )
    session.add(super_admin)
    await session.commit()
    await session.refresh(super_admin)

    return SuperAdminCompteRead(
        id=super_admin.id,
        nom=super_admin.nom,
        email=super_admin.email,
        statut=super_admin.statut,
        date_creation=super_admin.date_creation,
        derniere_connexion=super_admin.derniere_connexion,
    )


@router.patch("/comptes/{utilisateur_id}/statut", response_model=SuperAdminCompteRead)
async def update_compte_super_admin_statut(
    utilisateur_id: str,
    payload: SuperAdminStatutUpdate,
    session: SessionDep,
    current_super_admin: CurrentSuperAdmin,
) -> SuperAdminCompteRead:
    """Désactiver/réactiver un compte super-admin.

    Un super-admin ne peut pas désactiver son propre compte (même bug de
    verrouillage déjà rencontré côté comptes employés, aggravé ici car
    c'est un verrouillage au niveau plateforme).
    """
    if utilisateur_id == current_super_admin.id and payload.statut == "inactif":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Vous ne pouvez pas désactiver votre propre compte",
        )

    super_admin = await session.get(SuperAdmin, utilisateur_id)
    if super_admin is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Compte super-admin introuvable"
        )

    super_admin.statut = payload.statut
    session.add(super_admin)
    await session.commit()
    await session.refresh(super_admin)

    return SuperAdminCompteRead(
        id=super_admin.id,
        nom=super_admin.nom,
        email=super_admin.email,
        statut=super_admin.statut,
        date_creation=super_admin.date_creation,
        derniere_connexion=super_admin.derniere_connexion,
    )


@router.get("/entreprises/{entreprise_id}", response_model=EntrepriseSuperAdminDetailRead)
async def read_entreprise_detail(
    entreprise_id: str, session: SessionDep, current_super_admin: CurrentSuperAdmin
) -> EntrepriseSuperAdminDetailRead:
    """Détail complet d'une entreprise (n'importe laquelle) — pas de vérification tenant."""
    entreprise = await session.get(Entreprise, entreprise_id)
    if entreprise is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Entreprise introuvable"
        )

    summary = await _build_entreprise_summary(session, entreprise)

    utilisateurs_result = await session.execute(
        select(Utilisateur).where(Utilisateur.entreprise_id == entreprise_id)
    )
    utilisateurs = [
        UtilisateurSuperAdminRead(
            id=u.id,
            nom=u.nom,
            prenom=u.prenom,
            email=u.email,
            role=u.role,
            statut=u.statut,
            derniere_connexion=u.derniere_connexion,
        )
        for u in utilisateurs_result.scalars().all()
    ]

    clients_result = await session.execute(
        select(Client).where(Client.entreprise_id == entreprise_id)
    )
    clients = [
        ClientSuperAdminRead(
            id=c.id,
            nom=c.nom,
            prenom=c.prenom,
            telephone=c.telephone,
            email=c.email,
            statut=c.statut,
            derniere_connexion=c.derniere_connexion,
        )
        for c in clients_result.scalars().all()
    ]

    return EntrepriseSuperAdminDetailRead(
        **summary.model_dump(),
        utilisateurs=utilisateurs,
        clients=clients,
    )


@router.post(
    "/entreprises/{entreprise_id}/reinitialiser-installation",
    response_model=EntrepriseSuperAdminRead,
)
async def reinitialiser_installation(
    entreprise_id: str, session: SessionDep, current_super_admin: CurrentSuperAdmin
) -> EntrepriseSuperAdminRead:
    """Repasse `est_installe` à False ET génère un nouveau code d'installation
    — permet à l'entreprise de refaire l'installation bureau (ex. changement
    de machine). Génère explicitement le nouveau code ici plutôt que de
    compter sur `GET /entreprises/code-installation` : depuis que cet
    endpoint ne régénère plus automatiquement un code après une installation
    déjà consommée (voir entreprises.py::lire_code_installation), ne
    toucher qu'`est_installe` laisserait l'Admin bloqué sur "Installation
    terminée" sans aucun moyen d'obtenir un code utilisable."""
    entreprise = await session.get(Entreprise, entreprise_id)
    if entreprise is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Entreprise introuvable"
        )

    entreprise.est_installe = False
    session.add(entreprise)

    statement = select(CodeInstallation).where(
        CodeInstallation.entreprise_id == entreprise_id, CodeInstallation.utilise == False  # noqa: E712
    )
    anciens = (await session.execute(statement)).scalars().all()
    for ancien in anciens:
        await session.delete(ancien)
    session.add(
        CodeInstallation(entreprise_id=entreprise_id, code=generer_code_installation())
    )

    await session.commit()

    return await _build_entreprise_summary(session, entreprise)


@router.get(
    "/entreprises/{entreprise_id}/paiements", response_model=list[PaiementAbonnementRead]
)
async def read_entreprise_paiements(
    entreprise_id: str, session: SessionDep, current_super_admin: CurrentSuperAdmin
) -> list[PaiementAbonnement]:
    """Historique des paiements d'abonnement d'une entreprise (n'importe
    laquelle) — pas de vérification tenant, même niveau d'accès que
    `read_entreprise_detail`."""
    entreprise = await session.get(Entreprise, entreprise_id)
    if entreprise is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Entreprise introuvable"
        )

    result = await session.execute(
        select(PaiementAbonnement)
        .where(PaiementAbonnement.entreprise_id == entreprise_id)
        .order_by(PaiementAbonnement.date_paiement.desc())
    )
    return list(result.scalars().all())


@router.get("/paiements-en-attente", response_model=list[PaiementEnAttenteRead])
async def list_paiements_en_attente(
    session: SessionDep, current_super_admin: CurrentSuperAdmin
) -> list[PaiementEnAttenteRead]:
    """Paiements espèces déclarés par des tenants, tous confondus, en attente
    de confirmation — voir POST .../confirmer ci-dessous."""
    result = await session.execute(
        select(PaiementAbonnement, Entreprise.nom)
        .join(Entreprise, Entreprise.id == PaiementAbonnement.entreprise_id)
        .where(PaiementAbonnement.statut == "en_attente")
        .order_by(PaiementAbonnement.date_paiement.asc())
    )
    return [
        PaiementEnAttenteRead(**paiement.model_dump(), entreprise_nom=nom)
        for paiement, nom in result.all()
    ]


@router.post("/paiements/{paiement_id}/confirmer", response_model=PaiementAbonnementRead)
async def confirmer_paiement(
    paiement_id: str, session: SessionDep, current_super_admin: CurrentSuperAdmin
) -> PaiementAbonnement:
    """Confirme un paiement espèces déclaré par un tenant — active
    l'abonnement (même effet que verifier_abonnement pour MonCash)."""
    paiement = await session.get(PaiementAbonnement, paiement_id)
    if paiement is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Paiement introuvable"
        )
    if paiement.statut != "en_attente":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Ce paiement n'est plus en attente (statut actuel : {paiement.statut})",
        )

    abonnement = await session.get(Abonnement, paiement.abonnement_id)
    now = now_local()
    abonnement.statut = StatutAbonnement.ACTIF
    abonnement.date_paiement = now
    abonnement.date_renouvellement = (now + timedelta(days=365)).date()
    abonnement.montant = paiement.montant
    session.add(abonnement)

    paiement.statut = "confirme"
    paiement.date_paiement = now
    session.add(paiement)

    await session.commit()
    await session.refresh(paiement)
    return paiement


@router.post("/paiements/{paiement_id}/rejeter", response_model=PaiementAbonnementRead)
async def rejeter_paiement(
    paiement_id: str, session: SessionDep, current_super_admin: CurrentSuperAdmin
) -> PaiementAbonnement:
    """Rejette un paiement espèces déclaré par erreur ou frauduleusement —
    n'active jamais l'abonnement."""
    paiement = await session.get(PaiementAbonnement, paiement_id)
    if paiement is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Paiement introuvable"
        )
    if paiement.statut != "en_attente":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Ce paiement n'est plus en attente (statut actuel : {paiement.statut})",
        )

    paiement.statut = "rejete"
    session.add(paiement)
    await session.commit()
    await session.refresh(paiement)
    return paiement
