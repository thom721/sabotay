import base64
import json
import logging
from datetime import date, datetime, timedelta, timezone

import httpx
from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey, Ed25519PublicKey
from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select

from app.core.config import settings
from app.core.dt_utils import HAITI_TZ, now_local
from app.models.abonnement import Abonnement
from app.models.entreprise import Entreprise

logger = logging.getLogger("sabotaypro.licence")

VALIDITE_JOURS = 7

# Clé publique Ed25519 de la plateforme — même valeur que web/mobile
# (LicenceVerifier, licence_verifier.dart) et que la clé privée
# correspondante (LICENCE_PRIVATE_KEY, cloud uniquement). Utilisée ici pour
# qu'un poste local puisse vérifier lui-même un blob reçu du cloud, sans
# jamais détenir la clé privée.
LICENCE_PUBLIC_KEY_B64 = "jBbWT2x0xd+1BErKl38DWOkNZa2QjYJa3+Lvs6S/sFM="

# Même fenêtre de grâce que le client Dart (_kGraceHorsLigne) — tolère un
# poste local hors-ligne quelques jours au-delà de la fraîcheur du blob
# (VALIDITE_JOURS) avant de bloquer la collecte.
GRACE_HORS_LIGNE = timedelta(days=3)


def build_licence_payload(
    entreprise: Entreprise, abonnement: Abonnement, essai_jours: int
) -> dict:
    """Construit le payload de licence — le strict nécessaire pour qu'un
    client hors-ligne décide d'un accès, jamais de données de facturation."""
    now = datetime.now(timezone.utc)
    # entreprise.date_creation est naïve (heure locale Haïti, voir
    # core/dt_utils.py) — jamais sérialisée telle quelle : un client Dart
    # qui parse une chaîne ISO sans offset l'interprète comme heure locale
    # de l'appareil, pas Haïti. On rattache explicitement le fuseau avant
    # isoformat() pour que la chaîne porte un offset non ambigu.
    essai_fin = (entreprise.date_creation + timedelta(days=essai_jours)).replace(tzinfo=HAITI_TZ)
    return {
        "entreprise_id": entreprise.id,
        "entreprise_statut": entreprise.statut.value,
        "abonnement_statut": abonnement.statut.value,
        "date_renouvellement": (
            abonnement.date_renouvellement.isoformat()
            if abonnement.date_renouvellement
            else None
        ),
        "essai_fin": essai_fin.isoformat(),
        "issued_at": now.isoformat(),
        "valid_until": (now + timedelta(days=VALIDITE_JOURS)).isoformat(),
    }


def sign_payload(payload: dict) -> dict:
    """Signe `payload` avec la clé privée Ed25519 de la plateforme.

    Retourne `{data, signature}`, tous deux encodés en base64 — `data` est
    le JSON canonique du payload (avant signature), `signature` la
    signature Ed25519 de `data`. Lève 503 si aucune clé n'est configurée
    (environnements dev sans LICENCE_PRIVATE_KEY réglé)."""
    if not settings.LICENCE_PRIVATE_KEY:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="La signature de licence n'est pas configurée sur ce serveur.",
        )

    private_key = Ed25519PrivateKey.from_private_bytes(
        base64.b64decode(settings.LICENCE_PRIVATE_KEY)
    )
    data_bytes = json.dumps(payload, separators=(",", ":"), sort_keys=True).encode("utf-8")
    signature = private_key.sign(data_bytes)

    return {
        "data": base64.b64encode(data_bytes).decode("ascii"),
        "signature": base64.b64encode(signature).decode("ascii"),
    }


def verify_licence_blob(data_b64: str, signature_b64: str) -> dict | None:
    """Vérifie la signature Ed25519 d'un blob avec la clé publique de la
    plateforme et retourne le payload décodé, ou None si invalide/corrompu.
    Équivalent Python de `_verifierSignature` (licence_verifier.dart)."""
    try:
        public_key = Ed25519PublicKey.from_public_bytes(base64.b64decode(LICENCE_PUBLIC_KEY_B64))
        data_bytes = base64.b64decode(data_b64)
        public_key.verify(base64.b64decode(signature_b64), data_bytes)
        return json.loads(data_bytes)
    except (InvalidSignature, ValueError, KeyError, TypeError):
        return None


def _parse_datetime(value: str | None) -> datetime | None:
    return datetime.fromisoformat(value) if value else None


def acces_autorise_depuis_payload(payload: dict) -> bool:
    """Réplique côté serveur la décision allowed/warning/blocked de
    `LicenceVerifier._statutDepuisBlob` (Dart) — seul `blocked` interdit la
    collecte, `warning` reste autorisé (juste une bannière côté client, voir
    `licence_provider.dart`). Utilisé uniquement par
    `_abonnement_actif()` (transactions.py) en mode local."""
    now_utc = datetime.now(timezone.utc)

    entreprise_statut = payload.get("entreprise_statut")
    abonnement_statut = payload.get("abonnement_statut")

    date_renouvellement_str = payload.get("date_renouvellement")
    date_renouvellement = (
        date.fromisoformat(date_renouvellement_str) if date_renouvellement_str else None
    )
    essai_fin = _parse_datetime(payload.get("essai_fin"))
    valid_until = _parse_datetime(payload.get("valid_until"))

    # Une date de renouvellement (abonnement payé) encore valide l'emporte
    # sur la fraîcheur du blob — même règle que _abonnement_actif (branche
    # cloud) et que le client Dart.
    if date_renouvellement is not None and date_renouvellement >= now_utc.date():
        return True

    if entreprise_statut == "suspendu":
        return False

    if abonnement_statut == "actif":
        return True

    if abonnement_statut == "essai" and essai_fin is not None and essai_fin > now_utc:
        return True

    # Blob plus assez frais pour trancher, mais encore dans la fenêtre de
    # grâce hors-ligne — autorisé (avec avertissement côté client).
    if valid_until is not None and now_utc < valid_until + GRACE_HORS_LIGNE:
        return True

    return False


async def rafraichir_cache_local(session: AsyncSession) -> dict | None:
    """Récupère le blob de licence auprès du cloud (jeton de sync de ce
    poste), le vérifie et le met en cache local (`licence_cache_local`).
    Appelé par la boucle de sync périodique (main.py) et par
    `POST /setup/connecter` — jamais par `_abonnement_actif()` lui-même,
    pour que la collecte (hors-ligne par nature) ne dépende jamais d'un
    appel réseau synchrone. Retourne le payload vérifié, ou None en cas
    d'échec (réseau, signature invalide) — le dernier cache valide reste en
    place dans ce cas."""
    from app.models.licence_cache_local import LicenceCacheLocal

    if not settings.CLOUD_SYNC_URL or not settings.CLOUD_SYNC_TOKEN:
        return None

    try:
        async with httpx.AsyncClient(base_url=settings.CLOUD_SYNC_URL, timeout=15.0) as client:
            response = await client.get(
                "/api/v1/abonnement/licence",
                headers={"Authorization": f"Bearer {settings.CLOUD_SYNC_TOKEN}"},
            )
            response.raise_for_status()
            body = response.json()
    except (httpx.HTTPError, ValueError) as exc:
        logger.info("Rafraîchissement du cache de licence local échoué : %s", exc)
        return None

    payload = verify_licence_blob(body.get("data", ""), body.get("signature", ""))
    if payload is None:
        logger.warning("Blob de licence reçu du cloud invalide (signature) — cache non mis à jour")
        return None

    result = await session.execute(select(LicenceCacheLocal))
    cache = result.scalars().first()
    if cache is None:
        cache = LicenceCacheLocal(payload_json=json.dumps(payload), fetched_at=now_local())
    else:
        cache.payload_json = json.dumps(payload)
        cache.fetched_at = now_local()
    session.add(cache)
    await session.commit()
    return payload


async def abonnement_actif_local(session: AsyncSession) -> bool:
    """Équivalent de `_abonnement_actif()` (transactions.py) pour un poste
    local — lit uniquement le cache déjà vérifié (voir rafraichir_cache_local),
    jamais d'appel réseau ici. Si rien n'est encore en cache (tout premier
    lancement hors-ligne avant la première boucle de sync), autorise par
    défaut plutôt que de bloquer un utilisateur légitime — même choix que
    `_statutDepuisCache` côté Dart."""
    from app.models.licence_cache_local import LicenceCacheLocal

    result = await session.execute(select(LicenceCacheLocal))
    cache = result.scalars().first()
    if cache is None:
        return True

    try:
        payload = json.loads(cache.payload_json)
    except ValueError:
        return True

    return acces_autorise_depuis_payload(payload)
