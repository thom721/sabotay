import base64
import json
from datetime import datetime, timedelta, timezone

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from fastapi import HTTPException, status

from app.core.config import settings
from app.core.dt_utils import HAITI_TZ
from app.models.abonnement import Abonnement
from app.models.entreprise import Entreprise

VALIDITE_JOURS = 7


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
