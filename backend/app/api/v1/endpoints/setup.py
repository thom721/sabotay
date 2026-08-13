from typing import Annotated

import httpx
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import func, select

from app.core.config import settings, update_env_file
from app.core.db import get_session
from app.models.entreprise import Entreprise
from app.models.utilisateur import Utilisateur
from app.schemas.setup import SetupConnecterRequest, SetupConnecterResponse, SetupStatutRead

router = APIRouter(prefix="/setup", tags=["setup"])

SessionDep = Annotated[AsyncSession, Depends(get_session)]


def _require_local_mode() -> None:
    """Même garde-fou que `/sync/run` (voir sync.py) — ces endpoints n'ont
    de sens que sur un poste local, jamais sur le cloud multi-tenant."""
    if not settings.LOCAL_MODE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="/setup/* n'a de sens qu'en mode local (LOCAL_MODE=true)",
        )


@router.get("/statut", response_model=SetupStatutRead)
async def lire_statut_setup(session: SessionDep) -> SetupStatutRead:
    """État de la liaison au cloud d'un poste local — consulté par l'app
    desktop au démarrage pour décider d'afficher l'écran de connexion (code
    d'installation) ou de passer directement au login normal.

    `installation_terminee` est dérivé des données réellement présentes (au
    moins un utilisateur synchronisé), pas d'un simple flag de config — même
    principe que `_is_setup_done()` de pos_api (`db.query(User).count() > 0`) :
    survit à un `.env` qui contiendrait un jeton périmé/invalide sans
    qu'aucune donnée n'ait jamais été tirée avec succès."""
    _require_local_mode()

    lie_au_cloud = bool(settings.CLOUD_SYNC_URL and settings.CLOUD_SYNC_TOKEN)
    nb_utilisateurs = (
        await session.execute(select(func.count()).select_from(Utilisateur))
    ).scalar_one()

    entreprise_nom = None
    if nb_utilisateurs > 0:
        entreprise = (await session.execute(select(Entreprise))).scalars().first()
        entreprise_nom = entreprise.nom if entreprise else None

    return SetupStatutRead(
        installation_terminee=lie_au_cloud and nb_utilisateurs > 0,
        entreprise_nom=entreprise_nom,
    )


@router.post("/connecter", response_model=SetupConnecterResponse)
async def connecter_au_cloud(
    payload: SetupConnecterRequest, session: SessionDep
) -> SetupConnecterResponse:
    """Échange le code d'installation (Admin → Entreprise → Code
    d'installation, généré côté cloud) contre un jeton de sync, persiste
    `CLOUD_SYNC_URL`/`CLOUD_SYNC_TOKEN` dans `.env`, puis tire immédiatement
    les données de l'entreprise (n'attend pas la boucle périodique de 60s,
    voir `main.py`) pour que l'assistant d'installation puisse enchaîner sur
    le login sans délai perceptible."""
    _require_local_mode()

    if settings.CLOUD_SYNC_URL and settings.CLOUD_SYNC_TOKEN:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Ce poste est déjà connecté à une entreprise",
        )

    cloud_url = payload.cloud_url.rstrip("/")
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.post(
                f"{cloud_url}/api/v1/sync/redeem-code",
                json={"code": payload.code, "device_id": settings.DEVICE_ID},
            )
    except httpx.HTTPError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY, detail=f"Cloud injoignable : {exc}"
        )

    if response.status_code == 404:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Code d'installation invalide"
        )
    if response.status_code == 409:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail="Ce code a déjà été utilisé"
        )
    if response.status_code != 200:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY, detail="Erreur du serveur cloud"
        )

    token = response.json()["access_token"]

    update_env_file({"CLOUD_SYNC_URL": cloud_url, "CLOUD_SYNC_TOKEN": token})
    # Répercuté immédiatement sur l'objet en mémoire — Settings reste un
    # objet Python mutable ordinaire après instanciation, pas besoin de
    # redémarrer le service pour que la boucle de sync périodique en tienne compte.
    settings.CLOUD_SYNC_URL = cloud_url
    settings.CLOUD_SYNC_TOKEN = token

    from app.core import licence
    from app.services.local_sync_client import run_sync_cycle

    resultat = await run_sync_cycle()
    # Peuple immédiatement le cache de licence (voir licence.abonnement_actif_local)
    # — sans ça, la collecte resterait bloquée jusqu'au premier tick de la
    # boucle de sync périodique (jusqu'à 60s après la fin de cet appel).
    await licence.rafraichir_cache_local(session)

    nb_utilisateurs = (
        await session.execute(select(func.count()).select_from(Utilisateur))
    ).scalar_one()

    return SetupConnecterResponse(
        installation_terminee=nb_utilisateurs > 0,
        resultat_sync=resultat,
    )
