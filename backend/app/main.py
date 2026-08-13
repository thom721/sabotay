import asyncio
import contextlib
import logging
from typing import AsyncIterator

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.router import api_router
from app.core.config import settings

# Le logger racine est WARNING par défaut — sans ça, les logs applicatifs
# (ex. fallback console SMS/email en dev) n'apparaissent jamais.
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("sabotaypro.sync")

_SYNC_INTERVAL_SECONDS = 60


async def _boucle_sync_periodique() -> None:
    from app.services.local_sync_client import run_sync_cycle

    while True:
        await asyncio.sleep(_SYNC_INTERVAL_SECONDS)
        try:
            resultat = await run_sync_cycle()
            logger.info("Cycle de sync : %s", resultat)
        except Exception:
            logger.exception("Échec du cycle de sync périodique")


@contextlib.asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    tache_sync: asyncio.Task | None = None
    if settings.LOCAL_MODE:
        # Le SQLite local n'est jamais migré via Alembic (voir core/db.py) —
        # schéma dérivé des modèles actuels à chaque démarrage.
        from sqlmodel import SQLModel

        from app.core.db import engine

        async with engine.begin() as conn:
            await conn.run_sync(SQLModel.metadata.create_all)

        tache_sync = asyncio.create_task(_boucle_sync_periodique())

    yield

    if tache_sync is not None:
        tache_sync.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await tache_sync


app = FastAPI(title=settings.PROJECT_NAME, lifespan=lifespan)

# Dev : Flutter web tourne sur un port différent du backend (origine différente
# au sens CORS). Pas de cookies utilisés (auth par Bearer token), donc un
# wildcard est sans risque ici — à restreindre à un domaine précis en prod.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router, prefix="/api/v1")


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}
