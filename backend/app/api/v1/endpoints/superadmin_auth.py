from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import SQLModel, select

from app.core.db import get_session
from app.core.dt_utils import now_local
from app.core.security import create_access_token, verify_password
from app.models.super_admin import SuperAdmin
from app.schemas.auth import Token

router = APIRouter(prefix="/auth", tags=["superadmin-auth"])

SessionDep = Annotated[AsyncSession, Depends(get_session)]

_INVALID_CREDENTIALS_ERROR = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="Email ou mot de passe incorrect",
    headers={"WWW-Authenticate": "Bearer"},
)


class SuperAdminLoginRequest(SQLModel):
    email: str
    password: str


@router.post("/superadmin-login", response_model=Token)
async def superadmin_login(payload: SuperAdminLoginRequest, session: SessionDep) -> Token:
    statement = select(SuperAdmin).where(SuperAdmin.email == payload.email)
    result = await session.execute(statement)
    super_admin = result.scalar_one_or_none()

    if (
        super_admin is None
        or not verify_password(payload.password, super_admin.hashed_password)
        or super_admin.statut != "actif"
    ):
        raise _INVALID_CREDENTIALS_ERROR

    super_admin.derniere_connexion = now_local()
    session.add(super_admin)
    await session.commit()

    access_token = create_access_token(
        subject=str(super_admin.id),
        extra_claims={"type": "superadmin"},
    )
    return Token(access_token=access_token)
