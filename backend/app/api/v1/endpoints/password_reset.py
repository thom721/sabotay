from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

import app.crud.password_reset as crud_password_reset
from app.core.db import get_session
from app.core.notifications import send_email, send_sms
from app.core.security import generate_code, hash_password, verify_password
from app.crud.utilisateur import get_by_telephone_ou_email
from app.models.password_reset_token import CanalReset
from app.models.utilisateur import StatutUtilisateur
from app.schemas.password_reset import (
    PasswordResetConfirm,
    PasswordResetGenericResponse,
    PasswordResetRequest,
)

router = APIRouter(prefix="/auth", tags=["auth"])

SessionDep = Annotated[AsyncSession, Depends(get_session)]

_INVALID_CODE_ERROR = HTTPException(
    status_code=status.HTTP_400_BAD_REQUEST, detail="Code invalide ou expiré"
)


@router.post("/mot-de-passe-oublie", response_model=PasswordResetGenericResponse)
async def request_password_reset(
    payload: PasswordResetRequest, session: SessionDep
) -> PasswordResetGenericResponse:
    """Demande un code de réinitialisation. Réponse toujours générique — que
    l'utilisateur existe, soit actif, ou ait le canal demandé — pour éviter
    toute énumération de comptes."""
    user = await get_by_telephone_ou_email(session, payload.identifiant)

    if user is not None and user.statut == StatutUtilisateur.ACTIF:
        code = generate_code()
        await crud_password_reset.invalidate_active_for_user(session, user.id)
        await crud_password_reset.create(
            session, utilisateur_id=user.id, canal=payload.canal, code_plain=code
        )
        message = f"Votre code SabotayPro : {code}. Valable 15 minutes."

        if payload.canal == CanalReset.SMS:
            await send_sms(user.telephone, message)
        elif user.email is not None:
            await send_email(user.email, "Réinitialisation de mot de passe", message)

    return PasswordResetGenericResponse()


@router.post("/reinitialiser-mot-de-passe", response_model=PasswordResetGenericResponse)
async def confirm_password_reset(
    payload: PasswordResetConfirm, session: SessionDep
) -> PasswordResetGenericResponse:
    user = await get_by_telephone_ou_email(session, payload.identifiant)
    if user is None or user.statut != StatutUtilisateur.ACTIF:
        raise _INVALID_CODE_ERROR

    token = await crud_password_reset.get_active_for_user(session, user.id)
    if token is None:
        raise _INVALID_CODE_ERROR

    if not verify_password(payload.code, token.code_hash):
        await crud_password_reset.increment_attempts(session, token)
        raise _INVALID_CODE_ERROR

    await crud_password_reset.mark_used(session, token)
    user.hashed_password = hash_password(payload.nouveau_mot_de_passe)
    session.add(user)
    await session.commit()

    return PasswordResetGenericResponse(message="Mot de passe mis à jour")
