from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status

import app.crud.utilisateur as crud_utilisateur
from app.core.db import get_session
from app.core.deps import CurrentUser, TenantId, require_roles
from app.models.utilisateur import RoleUtilisateur, StatutUtilisateur
from app.schemas.utilisateur import (
    UtilisateurCreate,
    UtilisateurRead,
    UtilisateurRoleUpdate,
    UtilisateurStatutUpdate,
)
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(prefix="/utilisateurs", tags=["utilisateurs"])

SessionDep = Annotated[AsyncSession, Depends(get_session)]


@router.post(
    "",
    response_model=UtilisateurRead,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(require_roles(RoleUtilisateur.ADMIN))],
)
async def create_utilisateur(
    payload: UtilisateurCreate, session: SessionDep, entreprise_id: TenantId
) -> UtilisateurRead:
    """Invitation d'un employé par l'Admin Entreprise (PRD §8.2, RBAC §6)."""
    existing = await crud_utilisateur.get_by_telephone_ou_email(session, payload.telephone)
    if existing is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Ce numéro de téléphone est déjà associé à un compte",
        )
    return await crud_utilisateur.create(session, entreprise_id=entreprise_id, data=payload)


@router.get(
    "",
    response_model=list[UtilisateurRead],
    dependencies=[
        Depends(require_roles(RoleUtilisateur.ADMIN, RoleUtilisateur.MANAGER))
    ],
)
async def list_utilisateurs(
    session: SessionDep, entreprise_id: TenantId
) -> list[UtilisateurRead]:
    return await crud_utilisateur.list_for_tenant(session, entreprise_id=entreprise_id)


@router.patch(
    "/{utilisateur_id}/statut",
    response_model=UtilisateurRead,
    dependencies=[Depends(require_roles(RoleUtilisateur.ADMIN))],
)
async def update_utilisateur_statut(
    utilisateur_id: int,
    payload: UtilisateurStatutUpdate,
    session: SessionDep,
    entreprise_id: TenantId,
    current_user: CurrentUser,
) -> UtilisateurRead:
    """Désactiver/réactiver un compte employé (PRD §8.2)."""
    if utilisateur_id == current_user.id and payload.statut == StatutUtilisateur.INACTIF:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Vous ne pouvez pas désactiver votre propre compte",
        )

    utilisateur = await crud_utilisateur.get_for_tenant(
        session, utilisateur_id=utilisateur_id, entreprise_id=entreprise_id
    )
    if utilisateur is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Employé introuvable"
        )
    return await crud_utilisateur.update_statut(
        session, utilisateur=utilisateur, statut=payload.statut
    )


@router.patch(
    "/{utilisateur_id}/role",
    response_model=UtilisateurRead,
    dependencies=[Depends(require_roles(RoleUtilisateur.ADMIN))],
)
async def update_utilisateur_role(
    utilisateur_id: int,
    payload: UtilisateurRoleUpdate,
    session: SessionDep,
    entreprise_id: TenantId,
    current_user: CurrentUser,
) -> UtilisateurRead:
    """Changer le rôle d'un employé (Admin uniquement)."""
    if utilisateur_id == current_user.id and payload.role != RoleUtilisateur.ADMIN:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Vous ne pouvez pas changer votre propre rôle d'administrateur",
        )

    utilisateur = await crud_utilisateur.get_for_tenant(
        session, utilisateur_id=utilisateur_id, entreprise_id=entreprise_id
    )
    if utilisateur is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Employé introuvable"
        )
    return await crud_utilisateur.update_role(
        session, utilisateur=utilisateur, role=payload.role
    )
