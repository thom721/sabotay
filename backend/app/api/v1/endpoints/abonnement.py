from datetime import datetime, timedelta, timezone
from typing import Annotated

import httpx
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select

import app.crud.platform_config as crud_platform_config
from app.core import licence, moncash
from app.core.config import settings
from app.core.db import get_session
from app.core.deps import CurrentUser, TenantId, TenantIdOrSync, require_roles
from app.core.dt_utils import now_local
from app.core.moncash import MonCashNotConfiguredError
from app.models.abonnement import Abonnement, StatutAbonnement
from app.models.entreprise import Entreprise
from app.models.paiement_abonnement import PaiementAbonnement
from app.models.utilisateur import RoleUtilisateur
from app.schemas.abonnement import (
    AbonnementPayerResponse,
    AbonnementRead,
    AbonnementVerifierResponse,
    LicenceResponse,
    PaiementAbonnementRead,
)

router = APIRouter(prefix="/abonnement", tags=["abonnement"])

SessionDep = Annotated[AsyncSession, Depends(get_session)]

_INDISPONIBLE_EN_LOCAL = HTTPException(
    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
    detail=(
        "Gestion de l'abonnement indisponible en mode local — connectez-vous "
        "au web cloud pour payer ou vérifier votre abonnement."
    ),
)


async def _proxy_cloud_get(path: str):
    """Mode local (Phase 2a) uniquement : ces trois lectures (abonnement,
    historique de paiements, licence) n'ont pas de source de vérité locale
    — abonnements/paiements_abonnement ne sont jamais synchronisés (voir
    sync.py), et la clé privée de licence n'existe que côté cloud. On
    relaie donc l'appel avec le jeton de sync de cette installation."""
    if not settings.CLOUD_SYNC_URL or not settings.CLOUD_SYNC_TOKEN:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="CLOUD_SYNC_URL/CLOUD_SYNC_TOKEN non configurés sur ce poste local.",
        )
    async with httpx.AsyncClient(base_url=settings.CLOUD_SYNC_URL, timeout=15.0) as client:
        try:
            response = await client.get(
                f"/api/v1{path}",
                headers={"Authorization": f"Bearer {settings.CLOUD_SYNC_TOKEN}"},
            )
        except httpx.HTTPError as exc:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=f"Cloud injoignable : {exc}",
            ) from None
    if response.status_code >= 400:
        raise HTTPException(status_code=response.status_code, detail=response.text)
    return response.json()


async def _get_abonnement_for_tenant(session: SessionDep, entreprise_id: str) -> Abonnement:
    result = await session.execute(
        select(Abonnement).where(Abonnement.entreprise_id == entreprise_id)
    )
    abonnement = result.scalar_one_or_none()
    if abonnement is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Abonnement introuvable"
        )
    return abonnement


def _montant_renouvellement(platform_config) -> int:
    """Prix effectivement facturé à un (re)paiement — le prix de
    renouvellement annoncé s'il est configuré, sinon le prix courant. Seule
    source de vérité pour ce montant : voir payer_abonnement,
    verifier_abonnement, declarer_paiement_especes."""
    return platform_config.abonnement_renouvellement_htg or platform_config.abonnement_montant_htg


async def _to_abonnement_read(session: SessionDep, abonnement: Abonnement) -> AbonnementRead:
    platform_config = await crud_platform_config.get(session)
    return AbonnementRead(
        id=abonnement.id,
        entreprise_id=abonnement.entreprise_id,
        plan=abonnement.plan,
        statut=abonnement.statut,
        montant=abonnement.montant,
        date_debut=abonnement.date_debut,
        date_renouvellement=abonnement.date_renouvellement,
        date_paiement=abonnement.date_paiement,
        montant_prochain_renouvellement=_montant_renouvellement(platform_config),
    )


@router.get("", response_model=AbonnementRead)
async def read_abonnement(session: SessionDep, entreprise_id: TenantIdOrSync) -> AbonnementRead:
    """Consultation de l'abonnement du tenant courant (tout utilisateur staff
    authentifié, ou jeton de sync — voir _proxy_cloud_get)."""
    if settings.LOCAL_MODE:
        return await _proxy_cloud_get("/abonnement")
    abonnement = await _get_abonnement_for_tenant(session, entreprise_id)
    return await _to_abonnement_read(session, abonnement)


@router.get("/paiements", response_model=list[PaiementAbonnementRead])
async def read_paiements_abonnement(
    session: SessionDep, entreprise_id: TenantIdOrSync
) -> list[PaiementAbonnement]:
    """Historique des paiements de l'abonnement du tenant courant, du plus
    récent au plus ancien (tout utilisateur staff authentifié)."""
    if settings.LOCAL_MODE:
        return await _proxy_cloud_get("/abonnement/paiements")
    result = await session.execute(
        select(PaiementAbonnement)
        .where(PaiementAbonnement.entreprise_id == entreprise_id)
        .order_by(PaiementAbonnement.date_paiement.desc())
    )
    return list(result.scalars().all())


@router.get("/licence", response_model=LicenceResponse)
async def read_licence(session: SessionDep, entreprise_id: TenantIdOrSync) -> LicenceResponse:
    """Blob de licence signé (Ed25519), vérifiable côté client sans réseau
    (tout utilisateur staff authentifié). 503 si LICENCE_PRIVATE_KEY n'est
    pas configuré sur ce serveur (cf. app.core.licence.sign_payload). En
    mode local, jamais signé ici (pas de clé privée sur un poste local) —
    toujours relayé vers le cloud."""
    if settings.LOCAL_MODE:
        return await _proxy_cloud_get("/abonnement/licence")
    abonnement = await _get_abonnement_for_tenant(session, entreprise_id)
    entreprise = await session.get(Entreprise, entreprise_id)
    essai_jours = (await crud_platform_config.get(session)).essai_jours

    payload = licence.build_licence_payload(entreprise, abonnement, essai_jours)
    return LicenceResponse(**licence.sign_payload(payload))


@router.post(
    "/payer",
    response_model=AbonnementPayerResponse,
    dependencies=[Depends(require_roles(RoleUtilisateur.ADMIN))],
)
async def payer_abonnement(session: SessionDep, entreprise_id: TenantId) -> AbonnementPayerResponse:
    """Initie un paiement MonCash pour l'abonnement annuel (Admin uniquement)."""
    if settings.LOCAL_MODE:
        raise _INDISPONIBLE_EN_LOCAL
    abonnement = await _get_abonnement_for_tenant(session, entreprise_id)

    order_id = f"SABOTAYPRO-{entreprise_id}-{int(datetime.now(timezone.utc).timestamp())}"
    platform_config = await crud_platform_config.get(session)

    try:
        result = await moncash.create_payment(
            amount=_montant_renouvellement(platform_config), order_id=order_id
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
    session: SessionDep, entreprise_id: TenantId, current_user: CurrentUser
) -> AbonnementVerifierResponse:
    """Vérifie auprès de MonCash si le paiement de l'abonnement a été confirmé
    (Admin uniquement). Cas de polling normal : si pas encore payé, retourne
    `paye: false` sans lever d'erreur — le client réessaiera plus tard."""
    if settings.LOCAL_MODE:
        raise _INDISPONIBLE_EN_LOCAL
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
            paye=False, abonnement=await _to_abonnement_read(session, abonnement)
        )

    now = now_local()
    # Montant réellement facturé lors de POST /payer, pas l'ancien
    # abonnement.montant (qui ne reflète que le dernier paiement confirmé —
    # sinon un changement de prix entre-temps ne se répercute jamais).
    montant_paye = _montant_renouvellement(await crud_platform_config.get(session))
    abonnement.statut = StatutAbonnement.ACTIF
    abonnement.date_paiement = now
    abonnement.date_renouvellement = (now + timedelta(days=365)).date()
    abonnement.moncash_transaction_id = payment.get("transaction_id")
    abonnement.montant = montant_paye
    session.add(abonnement)
    session.add(
        PaiementAbonnement(
            abonnement_id=abonnement.id,
            entreprise_id=entreprise_id,
            montant=montant_paye,
            moncash_order_id=abonnement.moncash_order_id,
            moncash_transaction_id=abonnement.moncash_transaction_id,
            paye_par_id=current_user.id,
            paye_par_nom=current_user.nom,
            date_paiement=now,
        )
    )
    await session.commit()
    await session.refresh(abonnement)

    return AbonnementVerifierResponse(
        paye=True, abonnement=await _to_abonnement_read(session, abonnement)
    )


@router.post(
    "/declarer-especes",
    response_model=PaiementAbonnementRead,
    dependencies=[Depends(require_roles(RoleUtilisateur.ADMIN))],
)
async def declarer_paiement_especes(
    session: SessionDep, entreprise_id: TenantId, current_user: CurrentUser
) -> PaiementAbonnement:
    """Déclare un paiement en espèces pour l'abonnement (Admin uniquement) —
    même principe que pos_api (BillingPayment method='cash', status
    initialement 'pending') : reste `en_attente` tant qu'un superadmin ne l'a
    pas confirmé (POST /superadmin/paiements/{id}/confirmer). L'abonnement
    n'est activé qu'à la confirmation, jamais à la seule déclaration — sinon
    n'importe qui pourrait s'auto-activer sans payer."""
    if settings.LOCAL_MODE:
        raise _INDISPONIBLE_EN_LOCAL
    abonnement = await _get_abonnement_for_tenant(session, entreprise_id)
    platform_config = await crud_platform_config.get(session)

    paiement = PaiementAbonnement(
        abonnement_id=abonnement.id,
        entreprise_id=entreprise_id,
        montant=_montant_renouvellement(platform_config),
        methode="especes",
        statut="en_attente",
        paye_par_id=current_user.id,
        paye_par_nom=current_user.nom,
    )
    session.add(paiement)
    await session.commit()
    await session.refresh(paiement)
    return paiement


@router.post(
    "/marquer-paye-dev",
    response_model=AbonnementRead,
    dependencies=[Depends(require_roles(RoleUtilisateur.ADMIN))],
)
async def marquer_paye_dev(
    session: SessionDep, entreprise_id: TenantId, current_user: CurrentUser
) -> AbonnementRead:
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

    now = now_local()
    abonnement.statut = StatutAbonnement.ACTIF
    abonnement.date_paiement = now
    abonnement.date_renouvellement = (now + timedelta(days=365)).date()
    session.add(abonnement)
    session.add(
        PaiementAbonnement(
            abonnement_id=abonnement.id,
            entreprise_id=entreprise_id,
            montant=abonnement.montant,
            date_paiement=now,
            paye_par_id=current_user.id,
            paye_par_nom=current_user.nom,
        )
    )
    await session.commit()
    await session.refresh(abonnement)
    return await _to_abonnement_read(session, abonnement)
