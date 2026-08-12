from datetime import datetime, timedelta, timezone
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select

import app.crud.platform_config as crud_platform_config
from app.core import moncash
from app.core.config import settings
from app.core.db import get_session
from app.core.deps import TenantId, require_roles
from app.core.moncash import MonCashNotConfiguredError
from app.models.abonnement import Abonnement, StatutAbonnement
from app.models.utilisateur import RoleUtilisateur
from app.schemas.abonnement import (
    AbonnementPayerResponse,
    AbonnementRead,
    AbonnementVerifierResponse,
)

router = APIRouter(prefix="/abonnement", tags=["abonnement"])

SessionDep = Annotated[AsyncSession, Depends(get_session)]


async def _get_abonnement_for_tenant(session: SessionDep, entreprise_id: int) -> Abonnement:
    result = await session.execute(
        select(Abonnement).where(Abonnement.entreprise_id == entreprise_id)
    )
    abonnement = result.scalar_one_or_none()
    if abonnement is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Abonnement introuvable"
        )
    return abonnement


@router.get("", response_model=AbonnementRead)
async def read_abonnement(session: SessionDep, entreprise_id: TenantId) -> Abonnement:
    """Consultation de l'abonnement du tenant courant (tout utilisateur staff authentifié)."""
    return await _get_abonnement_for_tenant(session, entreprise_id)


@router.post(
    "/payer",
    response_model=AbonnementPayerResponse,
    dependencies=[Depends(require_roles(RoleUtilisateur.ADMIN))],
)
async def payer_abonnement(session: SessionDep, entreprise_id: TenantId) -> AbonnementPayerResponse:
    """Initie un paiement MonCash pour l'abonnement annuel (Admin uniquement)."""
    abonnement = await _get_abonnement_for_tenant(session, entreprise_id)

    order_id = f"SABOTAYPRO-{entreprise_id}-{int(datetime.now(timezone.utc).timestamp())}"
    platform_config = await crud_platform_config.get(session)

    try:
        result = await moncash.create_payment(
            amount=platform_config.abonnement_montant_htg, order_id=order_id
        )
    except MonCashNotConfiguredError:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Le paiement en ligne n'est pas configuré. Contactez l'administrateur système.",
        ) from None

    abonnement.moncash_order_id = order_id
    session.add(abonnement)
    await session.commit()

    return AbonnementPayerResponse(redirect_url=result["redirect_url"])


@router.post(
    "/verifier",
    response_model=AbonnementVerifierResponse,
    dependencies=[Depends(require_roles(RoleUtilisateur.ADMIN))],
)
async def verifier_abonnement(
    session: SessionDep, entreprise_id: TenantId
) -> AbonnementVerifierResponse:
    """Vérifie auprès de MonCash si le paiement de l'abonnement a été confirmé
    (Admin uniquement). Cas de polling normal : si pas encore payé, retourne
    `paye: false` sans lever d'erreur — le client réessaiera plus tard."""
    abonnement = await _get_abonnement_for_tenant(session, entreprise_id)

    if not abonnement.moncash_order_id:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Aucun paiement MonCash n'a été initié pour cet abonnement",
        )

    try:
        payment = await moncash.verify_payment(abonnement.moncash_order_id)
    except MonCashNotConfiguredError:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Le paiement en ligne n'est pas configuré. Contactez l'administrateur système.",
        ) from None

    if payment is None:
        return AbonnementVerifierResponse(
            paye=False, abonnement=AbonnementRead.model_validate(abonnement)
        )

    now = datetime.now(timezone.utc)
    abonnement.statut = StatutAbonnement.ACTIF
    abonnement.date_paiement = now
    abonnement.date_renouvellement = (now + timedelta(days=365)).date()
    abonnement.moncash_transaction_id = payment.get("transaction_id")
    session.add(abonnement)
    await session.commit()
    await session.refresh(abonnement)

    return AbonnementVerifierResponse(
        paye=True, abonnement=AbonnementRead.model_validate(abonnement)
    )


@router.post(
    "/marquer-paye-dev",
    response_model=AbonnementRead,
    dependencies=[Depends(require_roles(RoleUtilisateur.ADMIN))],
)
async def marquer_paye_dev(session: SessionDep, entreprise_id: TenantId) -> Abonnement:
    """DEV UNIQUEMENT — active l'abonnement du tenant sans passer par MonCash.

    Sert exclusivement à tester le blocage de POST /transactions tant qu'aucun
    identifiant marchand MonCash réel n'est disponible dans cet environnement.
    NE DOIT JAMAIS être atteignable en production : gardé par
    settings.ENVIRONMENT == "development", sinon 403.
    """
    if settings.ENVIRONMENT != "development":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Ce endpoint n'est disponible qu'en environnement de développement",
        )

    abonnement = await _get_abonnement_for_tenant(session, entreprise_id)

    now = datetime.now(timezone.utc)
    abonnement.statut = StatutAbonnement.ACTIF
    abonnement.date_paiement = now
    abonnement.date_renouvellement = (now + timedelta(days=365)).date()
    session.add(abonnement)
    await session.commit()
    await session.refresh(abonnement)
    return abonnement
