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
    from app.core import licence
    from app.core.db import async_session_maker
    from app.services.local_sync_client import run_sync_cycle

    while True:
        await asyncio.sleep(_SYNC_INTERVAL_SECONDS)
        try:
            resultat = await run_sync_cycle()
            logger.info("Cycle de sync : %s", resultat)
        except Exception:
            logger.exception("Échec du cycle de sync périodique")

        try:
            # Tient à jour le cache de licence dont dépend _abonnement_actif()
            # en mode local (voir transactions.py) — jamais d'appel réseau au
            # moment de la collecte elle-même, seulement ici.
            async with async_session_maker() as session:
                await licence.rafraichir_cache_local(session)
        except Exception:
            logger.exception("Échec du rafraîchissement du cache de licence local")


@contextlib.asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    tache_sync: asyncio.Task | None = None
    if settings.LOCAL_MODE:
        # Le SQLite local n'est jamais migré via Alembic (voir core/db.py) —
        # schéma dérivé des modèles actuels à chaque démarrage. create_all()
        # ne crée que les tables manquantes ; sync_schema_local() complète en
        # ajoutant les colonnes manquantes sur les tables déjà existantes
        # (même rôle que _sync_schema_from_models() côté pos_api).
        from sqlmodel import SQLModel

        from app.core.db import engine, sync_schema_local

        async with engine.begin() as conn:
            await conn.run_sync(SQLModel.metadata.create_all)
            await conn.run_sync(sync_schema_local)

        tache_sync = asyncio.create_task(_boucle_sync_periodique())

    yield

    if tache_sync is not None:
        tache_sync.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await tache_sync


app = FastAPI(title=settings.PROJECT_NAME, lifespan=lifespan)

# Dev : Flutter web tourne sur un port différent du backend (origine différente
# au sens CORS). Pas de cookies utilisés (auth par Bearer token), donc un
# wildcard est sans risque même en prod dans l'absolu — mais restreint via
# CORS_ORIGINS dès que réglé (voir Settings), pour qu'un domaine précis soit
# explicitement listé en déploiement réel plutôt que de compter sur "aucun
# cookie" comme unique garde-fou.
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router, prefix="/api/v1")


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}
