"""Client MonCash (paiement mobile Digicel Haïti) — API REST officielle.

Contrat vérifié dans la doc officielle MonCash :
- OAuth : POST /oauth/token (Basic Auth client_id/client_secret), form-encoded
  scope=read,write&grant_type=client_credentials. Le token expire en ~59s ; on
  n'en met donc jamais en cache, on en récupère un nouveau à chaque opération
  (création/vérification de paiement — opérations rares, donc sans impact).
- Création de paiement : POST /v1/CreatePayment, retourne un payment_token à
  utiliser dans l'URL de redirection {GATEWAY_BASE}/Payment/Redirect?token=...
- Vérification par orderId (on génère nous-même l'orderId, donc lookup fiable) :
  POST /v1/RetrieveOrderPayment. 404 ou statut non-200 = pas encore payé.
"""

from decimal import Decimal
from typing import Any

import httpx

from app.core.config import settings


class MonCashNotConfiguredError(RuntimeError):
    """Levée quand MONCASH_CLIENT_ID / MONCASH_CLIENT_SECRET ne sont pas définis."""


def _host_rest_api() -> str:
    if settings.MONCASH_MODE == "live":
        return "moncashbutton.digicelgroup.com/Api"
    return "sandbox.moncashbutton.digicelgroup.com/Api"


def _gateway_base() -> str:
    if settings.MONCASH_MODE == "live":
        return "https://moncashbutton.digicelgroup.com/Moncash-middleware"
    return "https://sandbox.moncashbutton.digicelgroup.com/Moncash-middleware"


async def _get_access_token() -> str:
    if not settings.MONCASH_CLIENT_ID or not settings.MONCASH_CLIENT_SECRET:
        raise MonCashNotConfiguredError(
            "MONCASH_CLIENT_ID / MONCASH_CLIENT_SECRET ne sont pas configurés"
        )

    url = f"https://{_host_rest_api()}/oauth/token"
    async with httpx.AsyncClient() as client:
        response = await client.post(
            url,
            auth=(settings.MONCASH_CLIENT_ID, settings.MONCASH_CLIENT_SECRET),
            headers={"Accept": "application/json"},
            data={"scope": "read,write", "grant_type": "client_credentials"},
        )
        response.raise_for_status()
        payload = response.json()
        return payload["access_token"]


async def create_payment(amount: Decimal | int | float, order_id: str) -> dict[str, Any]:
    """Crée un paiement MonCash et retourne l'URL de redirection vers le gateway."""
    access_token = await _get_access_token()

    url = f"https://{_host_rest_api()}/v1/CreatePayment"
    async with httpx.AsyncClient() as client:
        response = await client.post(
            url,
            headers={
                "Authorization": f"Bearer {access_token}",
                "Content-Type": "application/json",
            },
            json={"amount": float(amount), "orderId": order_id},
        )
        response.raise_for_status()
        payload = response.json()

    token = payload["payment_token"]["token"]
    redirect_url = f"{_gateway_base()}/Payment/Redirect?token={token}"
    return {"redirect_url": redirect_url, "token": token}


async def verify_payment(order_id: str) -> dict[str, Any] | None:
    """Vérifie un paiement par orderId. Retourne le dict `payment` si trouvé et
    payé, ou None si 404 (pas encore payé) ou toute autre réponse non-200."""
    access_token = await _get_access_token()

    url = f"https://{_host_rest_api()}/v1/RetrieveOrderPayment"
    async with httpx.AsyncClient() as client:
        response = await client.post(
            url,
            headers={
                "Authorization": f"Bearer {access_token}",
                "Content-Type": "application/json",
            },
            json={"orderId": order_id},
        )

    if response.status_code != 200:
        # 404 = pas encore payé, c'est un cas normal (polling) — pas une erreur.
        return None

    payload = response.json()
    return payload.get("payment")
