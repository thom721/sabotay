"""Client de synchronisation côté local (Phase 2a) — appelé uniquement
quand `settings.LOCAL_MODE`, par la boucle périodique (voir `main.py`) ou
manuellement via `POST /sync/run`. Pousse puis tire chaque entité du
registre dans l'ordre de dépendance (parents avant enfants — utile pour
l'intégrité référentielle à l'insertion, plus pour une réconciliation d'id :
les id sont des UUID générés à la construction de l'objet, jamais par une
séquence DB, donc toujours définitifs dès la création, cloud ou local)."""

from datetime import datetime

import httpx
from jose import jwt as jose_jwt
from sqlmodel import select

from app.api.v1.endpoints.sync import ENTITES, PUSH_ORDER
from app.core.config import settings
from app.core.db import async_session_maker
from app.core.dt_utils import now_local
from app.models.sync_state import SyncState


def _local_entreprise_id() -> str:
    claims = jose_jwt.get_unverified_claims(settings.CLOUD_SYNC_TOKEN)
    return str(claims["entreprise_id"])


async def _get_sync_state(session, entity: str) -> SyncState | None:
    result = await session.execute(
        select(SyncState).where(
            SyncState.device_id == settings.DEVICE_ID, SyncState.entity_name == entity
        )
    )
    return result.scalar_one_or_none()


async def _touch_watermark(session, entity: str, *, pushed_at=None, pulled_at=None) -> None:
    state = await _get_sync_state(session, entity)
    if state is None:
        state = SyncState(
            device_id=settings.DEVICE_ID,
            entreprise_id=_local_entreprise_id(),
            entity_name=entity,
        )
    if pushed_at is not None:
        state.last_push_at = pushed_at
    if pulled_at is not None:
        state.last_pull_at = pulled_at
    session.add(state)
    await session.commit()


async def _push_entity(client: httpx.AsyncClient, entity: str) -> int:
    model_cls = ENTITES[entity]

    async with async_session_maker() as session:
        state = await _get_sync_state(session, entity)
        watermark = state.last_push_at if state else None

        statement = select(model_cls)
        if watermark is not None:
            statement = statement.where(model_cls.updated_at > watermark)
        rows = list((await session.execute(statement)).scalars().all())
        if not rows:
            return 0
        records = [row.model_dump(mode="json") for row in rows]

    response = await client.post("/api/v1/sync/push", json={"entity": entity, "records": records})
    response.raise_for_status()

    async with async_session_maker() as session:
        await _touch_watermark(session, entity, pushed_at=now_local())

    return len(rows)


async def _pull_entity(client: httpx.AsyncClient, entity: str) -> int:
    model_cls = ENTITES[entity]

    async with async_session_maker() as session:
        state = await _get_sync_state(session, entity)
        since = state.last_pull_at if state else None

    total = 0
    while True:
        params: dict[str, str] = {"entity": entity}
        if since is not None:
            params["since"] = since.isoformat()

        response = await client.get("/api/v1/sync/pull", params=params)
        response.raise_for_status()
        data = response.json()
        records = data["records"]

        async with async_session_maker() as session:
            for record in records:
                incoming_id = record.get("id")
                existing = (
                    await session.get(model_cls, incoming_id) if incoming_id is not None else None
                )
                if existing is None:
                    session.add(model_cls.model_validate(record))
                    continue

                incoming_updated_at = record.get("updated_at")
                if incoming_updated_at is not None and existing.updated_at is not None:
                    parsed = datetime.fromisoformat(incoming_updated_at)
                    if parsed <= existing.updated_at:
                        continue
                # Validé (types Python réels) avant setattr — SQLite refuse
                # une chaîne JSON brute là où il attend un datetime/Decimal.
                validated = model_cls.model_validate(record)
                for key, value in validated.model_dump().items():
                    if key == "id":
                        continue
                    setattr(existing, key, value)
                session.add(existing)
            await session.commit()

        total += len(records)
        if data.get("next_since"):
            since = datetime.fromisoformat(data["next_since"])
        if not data.get("has_more"):
            break

    async with async_session_maker() as session:
        await _touch_watermark(session, entity, pulled_at=now_local())

    return total


async def run_sync_cycle() -> dict:
    if not settings.LOCAL_MODE:
        raise RuntimeError("run_sync_cycle ne doit être appelé qu'en mode local")
    if not settings.CLOUD_SYNC_URL or not settings.CLOUD_SYNC_TOKEN:
        return {"erreur": "CLOUD_SYNC_URL/CLOUD_SYNC_TOKEN non configurés"}

    resultats: dict[str, dict[str, int]] = {}
    try:
        async with httpx.AsyncClient(
            base_url=settings.CLOUD_SYNC_URL,
            headers={"Authorization": f"Bearer {settings.CLOUD_SYNC_TOKEN}"},
            timeout=30.0,
        ) as client:
            for entity in PUSH_ORDER:
                pushed = await _push_entity(client, entity)
                pulled = await _pull_entity(client, entity)
                resultats[entity] = {"pushed": pushed, "pulled": pulled}
    except httpx.HTTPError as exc:
        return {"erreur": f"Cloud injoignable : {exc}"}

    return resultats
