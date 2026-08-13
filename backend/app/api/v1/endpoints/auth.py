from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm

from app.core.db import get_session
from app.core.deps import CurrentUser
from app.core.dt_utils import now_local
from app.core.security import create_access_token, hash_password, verify_password
from app.crud.utilisateur import get_by_telephone_ou_email
from app.models.utilisateur import Utilisateur
from app.schemas.auth import MotDePasseUpdate, MotDePasseUpdateResponse, Token
from app.schemas.utilisateur import UtilisateurRead
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=Token)
async def login(
    session: Annotated[AsyncSession, Depends(get_session)],
    form_data: Annotated[OAuth2PasswordRequestForm, Depends()],
) -> Token:
    user = await get_by_telephone_ou_email(session, form_data.username)
    if user is None or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Téléphone/email ou mot de passe incorrect",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user.derniere_connexion = now_local()
    session.add(user)
    await session.commit()

    access_token = create_access_token(
        subject=str(user.id),
        extra_claims={"entreprise_id": user.entreprise_id, "role": user.role},
    )
    return Token(access_token=access_token)


@router.get("/me", response_model=UtilisateurRead)
async def read_current_user(current_user: CurrentUser) -> Utilisateur:
    return current_user


@router.patch("/mot-de-passe", response_model=MotDePasseUpdateResponse)
async def update_mot_de_passe(
    payload: MotDePasseUpdate,
    session: Annotated[AsyncSession, Depends(get_session)],
    current_user: CurrentUser,
) -> MotDePasseUpdateResponse:
    """Changement du mot de passe par l'utilisateur authentifié lui-même."""
    if not verify_password(payload.mot_de_passe_actuel, current_user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Mot de passe actuel incorrect",
        )

    current_user.hashed_password = hash_password(payload.nouveau_mot_de_passe)
    current_user.doit_changer_mot_de_passe = False
    session.add(current_user)
    await session.commit()
    return MotDePasseUpdateResponse()
