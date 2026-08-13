from typing import AsyncGenerator

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.core.config import settings

if settings.LOCAL_MODE:
    # Mode local (Phase 2a) : SQLite mono-tenant, jamais migré via Alembic —
    # voir le hook create_all() dans main.py. Le SQLite local n'est qu'un
    # cache/staging synchronisé avec le cloud, pas une source de vérité
    # versionnée, donc pas de dialecte Postgres-spécifique attendu ici.
    engine = create_async_engine(
        f"sqlite+aiosqlite:///{settings.LOCAL_DATABASE_PATH}", echo=False, future=True
    )
else:
    if not settings.DATABASE_URL:
        raise RuntimeError("DATABASE_URL est requis quand LOCAL_MODE=False")
    engine = create_async_engine(settings.DATABASE_URL, echo=False, future=True)

async_session_maker = async_sessionmaker(
    engine, class_=AsyncSession, expire_on_commit=False
)


async def get_session() -> AsyncGenerator[AsyncSession, None]:
    async with async_session_maker() as session:
        yield session
