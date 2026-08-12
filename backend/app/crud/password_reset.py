from datetime import datetime, timedelta, timezone

from sqlalchemy import update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select

from app.core.config import settings
from app.core.security import hash_password
from app.models.password_reset_token import CanalReset, PasswordResetToken


async def invalidate_active_for_user(session: AsyncSession, utilisateur_id: int) -> None:
    await session.execute(
        update(PasswordResetToken)
        .where(
            PasswordResetToken.utilisateur_id == utilisateur_id,
            PasswordResetToken.utilise == False,  # noqa: E712
        )
        .values(utilise=True)
    )


async def create(
    session: AsyncSession, *, utilisateur_id: int, canal: CanalReset, code_plain: str
) -> PasswordResetToken:
    token = PasswordResetToken(
        utilisateur_id=utilisateur_id,
        code_hash=hash_password(code_plain),
        canal=canal,
        date_expiration=datetime.now(timezone.utc)
        + timedelta(minutes=settings.PASSWORD_RESET_CODE_TTL_MINUTES),
    )
    session.add(token)
    await session.commit()
    await session.refresh(token)
    return token


async def get_active_for_user(
    session: AsyncSession, utilisateur_id: int
) -> PasswordResetToken | None:
    statement = select(PasswordResetToken).where(
        PasswordResetToken.utilisateur_id == utilisateur_id,
        PasswordResetToken.utilise == False,  # noqa: E712
        PasswordResetToken.date_expiration > datetime.now(timezone.utc),
        PasswordResetToken.tentatives < settings.PASSWORD_RESET_MAX_ATTEMPTS,
    )
    result = await session.execute(statement)
    return result.scalar_one_or_none()


async def mark_used(session: AsyncSession, token: PasswordResetToken) -> None:
    token.utilise = True
    session.add(token)
    await session.commit()


async def increment_attempts(session: AsyncSession, token: PasswordResetToken) -> None:
    token.tentatives += 1
    session.add(token)
    await session.commit()
