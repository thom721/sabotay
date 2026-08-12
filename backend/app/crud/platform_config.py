from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select

from app.models.platform_config import PlatformConfig


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


async def update(session: AsyncSession, *, montant: int, essai_jours: int) -> PlatformConfig:
    config = await get(session)
    config.abonnement_montant_htg = montant
    config.essai_jours = essai_jours
    session.add(config)
    await session.commit()
    await session.refresh(config)
    return config
