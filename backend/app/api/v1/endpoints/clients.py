from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status

import app.crud.client as crud_client
import app.crud.utilisateur as crud_utilisateur
from app.core.db import get_session
from app.core.deps import CurrentUser, TenantId, require_roles
from app.models.utilisateur import RoleUtilisateur
from app.schemas.client import ClientAssignAgent, ClientCreate, ClientRead
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(prefix="/clients", tags=["clients"])

SessionDep = Annotated[AsyncSession, Depends(get_session)]


@router.post(
    "",
    response_model=ClientRead,
    status_code=status.HTTP_201_CREATED,
    dependencies=[
        Depends(
            require_roles(
                RoleUtilisateur.ADMIN, RoleUtilisateur.MANAGER, RoleUtilisateur.AGENT
            )
        )
    ],
)
async def create_client(
    payload: ClientCreate, session: SessionDep, entreprise_id: TenantId
) -> ClientRead:
    duplicate = await crud_client.find_duplicate(
        session,
        entreprise_id=entreprise_id,
        nom=payload.nom,
        prenom=payload.prenom,
        date_naissance=payload.date_naissance,
        nif_cin=payload.nif_cin,
    )
    if duplicate is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "message": "Un client avec ces informations existe déjà",
                "client_existant_id": duplicate.id,
                "client_existant_nom": f"{duplicate.prenom} {duplicate.nom}",
            },
        )

    client = await crud_client.create(
        session, entreprise_id=entreprise_id, data=payload.model_dump()
    )
    return client


@router.get("", response_model=list[ClientRead])
async def list_clients(
    session: SessionDep, entreprise_id: TenantId, current_user: CurrentUser
) -> list[ClientRead]:
    # Un agent ne voit que ses clients assignés ; Admin/Manager voient tout (PRD §6).
    agent_id = current_user.id if current_user.role == RoleUtilisateur.AGENT else None
    clients = await crud_client.list_for_tenant(
        session, entreprise_id=entreprise_id, agent_id=agent_id
    )
    return clients


@router.get("/{client_id}", response_model=ClientRead)
async def get_client(
    client_id: str, session: SessionDep, entreprise_id: TenantId
) -> ClientRead:
    client = await crud_client.get_for_tenant(
        session, client_id=client_id, entreprise_id=entreprise_id
    )
    if client is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Client introuvable")
    return client


@router.patch(
    "/{client_id}/agent",
    response_model=ClientRead,
    dependencies=[
        Depends(require_roles(RoleUtilisateur.ADMIN, RoleUtilisateur.MANAGER))
    ],
)
async def assign_client_agent(
    client_id: str, payload: ClientAssignAgent, session: SessionDep, entreprise_id: TenantId
) -> ClientRead:
    """Assigner/réassigner un client à un agent (PRD §8.2)."""
    client = await crud_client.get_for_tenant(
        session, client_id=client_id, entreprise_id=entreprise_id
    )
    if client is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Client introuvable")

    if payload.agent_assigne_id is not None:
        agent = await crud_utilisateur.get_for_tenant(
            session, utilisateur_id=payload.agent_assigne_id, entreprise_id=entreprise_id
        )
        if agent is None or agent.role != RoleUtilisateur.AGENT:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="L'utilisateur assigné doit être un agent de cette entreprise",
            )

    return await crud_client.assign_agent(
        session, client=client, agent_assigne_id=payload.agent_assigne_id
    )
