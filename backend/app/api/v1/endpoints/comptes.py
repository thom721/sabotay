from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status

import app.crud.client as crud_client
import app.crud.compte_sabotay as crud_compte
import app.crud.transaction as crud_transaction
from app.core.db import get_session
from app.core.deps import CurrentClient, CurrentUser, TenantId, require_roles
from app.models.utilisateur import RoleUtilisateur
from app.schemas.compte_sabotay import (
    CompteSabotayCreate,
    CompteSabotayPage,
    CompteSabotayRead,
    CompteSabotaySolde,
)
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(tags=["comptes-sabotay"])

SessionDep = Annotated[AsyncSession, Depends(get_session)]


@router.get(
    "/comptes",
    response_model=CompteSabotayPage,
    dependencies=[
        Depends(
            require_roles(
                RoleUtilisateur.ADMIN, RoleUtilisateur.MANAGER, RoleUtilisateur.AGENT
            )
        )
    ],
)
async def list_comptes(
    session: SessionDep,
    entreprise_id: TenantId,
    current_user: CurrentUser,
    skip: int = 0,
    limit: int = 200,
) -> CompteSabotayPage:
    """Registre tenant-wide avec solde inline — pour le cache offline mobile
    (Epic 6) : un seul appel plutôt qu'un `/comptes/{id}/solde` par compte
    lors du peuplement du cache. Un Agent ne voit que les comptes des
    clients qui lui sont assignés, comme `GET /clients`."""
    agent_id = current_user.id if current_user.role == RoleUtilisateur.AGENT else None
    comptes, total = await crud_compte.list_for_tenant_avec_soldes(
        session,
        entreprise_id=entreprise_id,
        agent_id=agent_id,
        skip=skip,
        limit=min(limit, 200),
    )
    return CompteSabotayPage(items=comptes, total=total)


@router.post(
    "/comptes",
    response_model=CompteSabotayRead,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(require_roles(RoleUtilisateur.ADMIN, RoleUtilisateur.MANAGER))],
)
async def create_compte(
    payload: CompteSabotayCreate, session: SessionDep, entreprise_id: TenantId
) -> CompteSabotayRead:
    client = await crud_client.get_for_tenant(
        session, client_id=payload.client_id, entreprise_id=entreprise_id
    )
    if client is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Client introuvable")

    compte = await crud_compte.create(session, entreprise_id=entreprise_id, data=payload)
    return compte


@router.get(
    "/comptes/numero/{numero_compte}",
    response_model=CompteSabotayRead,
    dependencies=[
        Depends(
            require_roles(
                RoleUtilisateur.ADMIN, RoleUtilisateur.MANAGER, RoleUtilisateur.AGENT
            )
        )
    ],
)
async def get_compte_by_numero(
    numero_compte: str, session: SessionDep, entreprise_id: TenantId
) -> CompteSabotayRead:
    compte = await crud_compte.get_by_numero(
        session, numero_compte=numero_compte, entreprise_id=entreprise_id
    )
    if compte is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Compte introuvable")
    return compte


@router.get("/comptes/{compte_id}", response_model=CompteSabotayRead)
async def get_compte(
    compte_id: str, session: SessionDep, entreprise_id: TenantId
) -> CompteSabotayRead:
    compte = await crud_compte.get_for_tenant(
        session, compte_id=compte_id, entreprise_id=entreprise_id
    )
    if compte is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Compte introuvable")
    return compte


@router.get("/comptes/{compte_id}/solde", response_model=CompteSabotaySolde)
async def get_compte_solde(
    compte_id: str, session: SessionDep, entreprise_id: TenantId
) -> CompteSabotaySolde:
    compte = await crud_compte.get_for_tenant(
        session, compte_id=compte_id, entreprise_id=entreprise_id
    )
    if compte is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Compte introuvable")
    return await crud_transaction.get_solde(session, compte=compte)


@router.get("/clients/moi/comptes", response_model=list[CompteSabotayRead])
async def list_comptes_for_current_client(
    session: SessionDep, current_client: CurrentClient
) -> list[CompteSabotayRead]:
    return await crud_compte.list_for_client(
        session, client_id=current_client.id, entreprise_id=current_client.entreprise_id
    )


@router.get("/clients/{client_id}/comptes", response_model=list[CompteSabotayRead])
async def list_comptes_for_client(
    client_id: str, session: SessionDep, entreprise_id: TenantId
) -> list[CompteSabotayRead]:
    client = await crud_client.get_for_tenant(
        session, client_id=client_id, entreprise_id=entreprise_id
    )
    if client is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Client introuvable")
    return await crud_compte.list_for_client(
        session, client_id=client_id, entreprise_id=entreprise_id
    )
