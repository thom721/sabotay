import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.router import api_router
from app.core.config import settings

# Le logger racine est WARNING par défaut — sans ça, les logs applicatifs
# (ex. fallback console SMS/email en dev) n'apparaissent jamais.
logging.basicConfig(level=logging.INFO)

app = FastAPI(title=settings.PROJECT_NAME)

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
