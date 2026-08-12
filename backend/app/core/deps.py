from typing import Annotated

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select

from app.core.db import get_session
from app.core.security import decode_access_token
from app.models.client import Client, StatutClient
from app.models.super_admin import SuperAdmin
from app.models.utilisateur import RoleUtilisateur, StatutUtilisateur, Utilisateur

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")

SessionDep = Annotated[AsyncSession, Depends(get_session)]


async def get_current_user(
    session: SessionDep, token: Annotated[str, Depends(oauth2_scheme)]
) -> Utilisateur:
    credentials_error = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Identifiants invalides",
        headers={"WWW-Authenticate": "Bearer"},
    )

    payload = decode_access_token(token)
    if payload is None:
        raise credentials_error

    # Un token client (payload "type" == "client") ne doit jamais authentifier
    # un principal staff, même si le "sub" coïncide avec un id d'utilisateur.
    if payload.get("type") is not None:
        raise credentials_error

    user_id = payload.get("sub")
    if user_id is None:
        raise credentials_error

    user = await session.get(Utilisateur, int(user_id))
    if user is None or user.statut != StatutUtilisateur.ACTIF:
        raise credentials_error

    return user


CurrentUser = Annotated[Utilisateur, Depends(get_current_user)]


async def get_current_client(
    session: SessionDep, token: Annotated[str, Depends(oauth2_scheme)]
) -> Client:
    credentials_error = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Identifiants invalides",
        headers={"WWW-Authenticate": "Bearer"},
    )

    payload = decode_access_token(token)
    if payload is None:
        raise credentials_error

    if payload.get("type") != "client":
        raise credentials_error

    client_id = payload.get("sub")
    if client_id is None:
        raise credentials_error

    client = await session.get(Client, int(client_id))
    if client is None or client.statut != StatutClient.ACTIF:
        raise credentials_error

    return client


CurrentClient = Annotated[Client, Depends(get_current_client)]


async def get_current_super_admin(
    session: SessionDep, token: Annotated[str, Depends(oauth2_scheme)]
) -> SuperAdmin:
    credentials_error = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Identifiants invalides",
        headers={"WWW-Authenticate": "Bearer"},
    )

    payload = decode_access_token(token)
    if payload is None:
        raise credentials_error

    if payload.get("type") != "superadmin":
        raise credentials_error

    super_admin_id = payload.get("sub")
    if super_admin_id is None:
        raise credentials_error

    super_admin = await session.get(SuperAdmin, int(super_admin_id))
    if super_admin is None or super_admin.statut != "actif":
        raise credentials_error

    return super_admin


CurrentSuperAdmin = Annotated[SuperAdmin, Depends(get_current_super_admin)]


def require_roles(*allowed_roles: RoleUtilisateur):
    async def _check_role(current_user: CurrentUser) -> Utilisateur:
        if current_user.role not in allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Vous n'avez pas la permission d'effectuer cette action",
            )
        return current_user

    return _check_role


def get_tenant_id(current_user: CurrentUser) -> int:
    """Isolation multi-tenant : toute requête scoped par entreprise_id doit
    passer par cette dépendance plutôt que faire confiance à un paramètre client."""
    return current_user.entreprise_id


TenantId = Annotated[int, Depends(get_tenant_id)]
