from decimal import Decimal
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select

import app.crud.platform_config as crud_platform_config
from app.core.db import get_session
from app.core.deps import CurrentSuperAdmin
from app.core.security import hash_password
from app.models.abonnement import Abonnement, StatutAbonnement
from app.models.client import Client
from app.models.entreprise import Entreprise
from app.models.super_admin import SuperAdmin
from app.models.transaction import Transaction, TypeTransaction
from app.models.utilisateur import Utilisateur
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


@router.get("/config", response_model=PlatformConfigRead)
async def read_platform_config(
    session: SessionDep, current_super_admin: CurrentSuperAdmin
) -> PlatformConfigRead:
    """Réglages globaux de la plateforme (aujourd'hui : prix de l'abonnement
    annuel en HTG, appliqué à toutes les entreprises)."""
    return await crud_platform_config.get(session)


@router.patch("/config", response_model=PlatformConfigRead)
async def update_platform_config(
    payload: PlatformConfigUpdate,
    session: SessionDep,
    current_super_admin: CurrentSuperAdmin,
) -> PlatformConfigRead:
    if payload.abonnement_montant_htg <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Le montant doit être positif"
        )
    if payload.essai_jours <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le nombre de jours d'essai doit être positif",
        )
    return await crud_platform_config.update(
        session, montant=payload.abonnement_montant_htg, essai_jours=payload.essai_jours
    )


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
    utilisateur_id: int,
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
    entreprise_id: int, session: SessionDep, current_super_admin: CurrentSuperAdmin
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
