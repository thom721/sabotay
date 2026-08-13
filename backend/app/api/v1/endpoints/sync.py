from datetime import datetime, timedelta, timezone
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import SQLModel, select

from app.core.config import settings
from app.core.db import get_session
from app.core.deps import CurrentSyncDevice, TenantId, require_roles
from app.core.dt_utils import now_local
from app.core.security import create_access_token, verify_password
from app.crud.utilisateur import get_by_telephone_ou_email
from app.models.client import Client
from app.models.code_installation import CodeInstallation
from app.models.compte_sabotay import CompteSabotay
from app.models.entreprise import Entreprise
from app.models.sync_state import SyncState
from app.models.transaction import Transaction
from app.models.utilisateur import RoleUtilisateur, Utilisateur
from app.schemas.auth import Token
from app.schemas.sync import (
    PullResponse,
    PushRequest,
    PushResponse,
    RedeemCodeRequest,
    SyncStatusEntry,
    SyncTokenRequest,
)

router = APIRouter(prefix="/sync", tags=["sync"])

SessionDep = Annotated[AsyncSession, Depends(get_session)]

# Registre d'entités synchronisables — utilisé tel quel côté cloud et côté
# local (même codebase). abonnements/paiements_abonnement/super_admins/
# platform_config/password_reset_tokens n'y figurent jamais : ce sont des
# données de facturation/plateforme, une seule source de vérité (le cloud),
# jamais dupliquées sur un poste local (voir abonnement.py en mode local).
ENTITES: dict[str, type[SQLModel]] = {
    "entreprises": Entreprise,
    "utilisateurs": Utilisateur,
    "clients": Client,
    "comptes_sabotay": CompteSabotay,
    "transactions": Transaction,
}

# Ordre de dépendance (parents avant enfants) — entreprises n'a en pratique
# jamais de nouvelle ligne créée localement (une entreprise existe déjà,
# pulled une fois), donc jamais d'id négatif à reconcilier pour elle, mais
# elle reste dans ENTITES pour que son profil (nom, devise, frais_retrait…)
# se synchronise dans les deux sens.
PUSH_ORDER = ["entreprises", "utilisateurs", "clients", "comptes_sabotay", "transactions"]

_PAGE_SIZE = 200


def _tenant_filter(model_cls: type[SQLModel], entreprise_id: str):
    if model_cls is Entreprise:
        return model_cls.id == entreprise_id
    return model_cls.entreprise_id == entreprise_id


def _get_model(entity: str) -> type[SQLModel]:
    model_cls = ENTITES.get(entity)
    if model_cls is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Entité inconnue: {entity}")
    return model_cls


@router.post("/token", response_model=Token)
async def create_sync_token(payload: SyncTokenRequest, session: SessionDep) -> Token:
    """Échange les identifiants d'un Admin contre un jeton longue durée
    (365 jours, `type: "sync"`) — jamais utilisé pour naviguer dans l'app,
    uniquement pour les appels POST/GET /sync/* d'un poste local vers le
    cloud."""
    user = await get_by_telephone_ou_email(session, payload.identifiant)
    if user is None or not verify_password(payload.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Identifiants invalides"
        )
    if user.role != RoleUtilisateur.ADMIN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Seul un Admin peut générer un jeton de synchronisation",
        )

    token = create_access_token(
        subject=str(user.id),
        extra_claims={
            "type": "sync",
            "entreprise_id": user.entreprise_id,
            "device_id": payload.device_id,
        },
        expires_delta=timedelta(days=365),
    )
    return Token(access_token=token)


@router.post("/redeem-code", response_model=Token)
async def redeem_code(payload: RedeemCodeRequest, session: SessionDep) -> Token:
    """Échange un code d'installation contre un jeton de sync — alternative
    à `POST /sync/token` (email/mot de passe) pour l'assistant d'installation
    bureau (Epic 5) : l'utilisateur n'a besoin que du code affiché dans
    Admin → Entreprise, pas de taper ses identifiants sur le poste local.
    Contrairement à pos_api, pas d'étape de "claim" séparée — la
    consommation du code EST la finalisation (voir CodeInstallation)."""
    code = payload.code.strip().upper()
    statement = select(CodeInstallation).where(CodeInstallation.code == code)
    installation = (await session.execute(statement)).scalar_one_or_none()
    if installation is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Code d'installation invalide"
        )
    if installation.utilise:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Ce code a déjà été utilisé — générez-en un nouveau depuis Admin → Entreprise",
        )

    statement_admin = select(Utilisateur).where(
        Utilisateur.entreprise_id == installation.entreprise_id,
        Utilisateur.role == RoleUtilisateur.ADMIN,
    )
    admin = (await session.execute(statement_admin)).scalars().first()
    if admin is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Aucun compte Admin pour cette entreprise"
        )

    installation.utilise = True
    installation.utilise_le = now_local()
    session.add(installation)
    await session.commit()

    token = create_access_token(
        subject=str(admin.id),
        extra_claims={
            "type": "sync",
            "entreprise_id": installation.entreprise_id,
            "device_id": payload.device_id,
        },
        expires_delta=timedelta(days=365),
    )
    return Token(access_token=token)


async def _touch_sync_state(
    session: SessionDep, device: CurrentSyncDevice, entity: str, *, pushed: bool = False, pulled: bool = False
) -> None:
    result = await session.execute(
        select(SyncState).where(
            SyncState.device_id == device.device_id, SyncState.entity_name == entity
        )
    )
    state = result.scalar_one_or_none()
    if state is None:
        state = SyncState(
            device_id=device.device_id, entreprise_id=device.entreprise_id, entity_name=entity
        )
    now = now_local()
    if pushed:
        state.last_push_at = now
    if pulled:
        state.last_pull_at = now
    session.add(state)

    # Première synchronisation réussie (n'importe quelle entité) pour cette
    # entreprise = installation bureau terminée. Jamais réglé manuellement à
    # True ailleurs — voir Entreprise.est_installe. Idempotent (no-op une
    # fois déjà à True), donc pas besoin de distinguer "première" fois
    # explicitement.
    entreprise = await session.get(Entreprise, device.entreprise_id)
    if entreprise is not None and not entreprise.est_installe:
        entreprise.est_installe = True
        session.add(entreprise)

    await session.commit()


@router.post("/push", response_model=PushResponse)
async def push(
    payload: PushRequest, session: SessionDep, device: CurrentSyncDevice
) -> PushResponse:
    model_cls = _get_model(payload.entity)

    for raw in payload.records:
        record = dict(raw)
        # entreprise_id n'est jamais fait confiance au payload — toujours
        # dérivé du jeton de sync, même règle que TenantId pour les requêtes
        # staff normales.
        if model_cls is Entreprise:
            record["id"] = device.entreprise_id
        else:
            record["entreprise_id"] = device.entreprise_id

        incoming_id = record.get("id")

        # Un id est toujours définitif (UUID généré à la construction de
        # l'objet, cloud ou local — jamais par une séquence DB) : pas de
        # notion de placeholder à réconcilier ici, juste upsert par id.
        existing = await session.get(model_cls, incoming_id) if incoming_id is not None else None
        existing_entreprise_id = existing.id if model_cls is Entreprise else getattr(
            existing, "entreprise_id", None
        )
        if existing is not None and existing_entreprise_id != device.entreprise_id:
            # Jamais écraser une ligne d'une autre entreprise (id > 0
            # théoriquement toujours propre à ce tenant, filet de sécurité).
            continue

        if existing is None:
            obj = model_cls.model_validate(record)
            session.add(obj)
            continue

        incoming_updated_at = record.get("updated_at")
        if incoming_updated_at is not None and existing.updated_at is not None:
            parsed = (
                datetime.fromisoformat(incoming_updated_at)
                if isinstance(incoming_updated_at, str)
                else incoming_updated_at
            )
            if parsed <= existing.updated_at:
                continue  # le cloud a déjà une version plus récente ou égale

        # Validé (donc typé : datetime/Decimal/enum réels, pas les chaînes
        # JSON brutes de `record`) avant setattr — SQLite est strict sur les
        # types Python attendus par ses colonnes, contrairement à Postgres.
        validated = model_cls.model_validate(record)
        for key, value in validated.model_dump().items():
            if key == "id":
                continue
            setattr(existing, key, value)
        session.add(existing)

    await session.commit()
    await _touch_sync_state(session, device, payload.entity, pushed=True)
    return PushResponse()


@router.get("/pull", response_model=PullResponse)
async def pull(
    session: SessionDep,
    device: CurrentSyncDevice,
    entity: str = Query(...),
    since: datetime | None = Query(default=None),
) -> PullResponse:
    model_cls = _get_model(entity)

    statement = (
        select(model_cls)
        .where(_tenant_filter(model_cls, device.entreprise_id))
        .order_by(model_cls.updated_at)
        .limit(_PAGE_SIZE + 1)
    )
    if since is not None:
        statement = statement.where(model_cls.updated_at > since)

    rows = list((await session.execute(statement)).scalars().all())
    has_more = len(rows) > _PAGE_SIZE
    rows = rows[:_PAGE_SIZE]

    await _touch_sync_state(session, device, entity, pulled=True)

    return PullResponse(
        records=[row.model_dump(mode="json") for row in rows],
        has_more=has_more,
        next_since=rows[-1].updated_at if rows else since,
    )


@router.post("/run")
async def trigger_sync_run(current_user=Depends(require_roles(RoleUtilisateur.ADMIN))) -> dict:
    """Déclenche manuellement un cycle de synchronisation — n'a de sens que
    sur un poste local (LOCAL_MODE=true) ; sur le cloud, il n'y a rien à
    synchroniser "vers" (le cloud est la destination, pas la source)."""
    if not settings.LOCAL_MODE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="POST /sync/run n'a de sens qu'en mode local (LOCAL_MODE=true)",
        )
    from app.services.local_sync_client import run_sync_cycle

    return await run_sync_cycle()


@router.get("/status", response_model=list[SyncStatusEntry])
async def read_sync_status(
    session: SessionDep,
    entreprise_id: TenantId,
    current_user=Depends(require_roles(RoleUtilisateur.ADMIN)),
) -> list[SyncState]:
    """État de la synchronisation pour le tenant courant — côté cloud,
    montre tous les devices de cette entreprise ; côté local, un seul
    (`DEVICE_ID`, "self" par défaut)."""
    result = await session.execute(
        select(SyncState).where(SyncState.entreprise_id == entreprise_id)
    )
    return list(result.scalars().all())
