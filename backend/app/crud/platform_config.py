from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select

from app.models.platform_config import PlatformConfig
from app.schemas.superadmin import PlatformConfigUpdate


async def get(session: AsyncSession) -> PlatformConfig:
    result = await session.execute(select(PlatformConfig).limit(1))
    config = result.scalar_one_or_none()
    if config is None:
        # Filet de sécurité si la ligne seed de la migration 0014 manque.
        config = PlatformConfig()
        session.add(config)
        await session.commit()
        await session.refresh(config)
    return config


async def update(session: AsyncSession, payload: PlatformConfigUpdate) -> PlatformConfig:
    """PATCH partiel : n'écrase que les champs explicitement fournis — un
    onglet Paramètres (Abonnement, Email) ne touche jamais les champs des
    autres onglets."""
    config = await get(session)
    for key, value in payload.model_dump(exclude_unset=True, exclude_none=True).items():
        setattr(config, key, value)
    session.add(config)
    await session.commit()
    await session.refresh(config)
    return config
