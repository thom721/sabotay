from datetime import datetime
from typing import Any

from sqlmodel import SQLModel


class SyncTokenRequest(SQLModel):
    identifiant: str
    password: str
    device_id: str


class RedeemCodeRequest(SQLModel):
    code: str
    device_id: str = "installer"


class PushRequest(SQLModel):
    entity: str
    records: list[dict[str, Any]]


class PushResponse(SQLModel):
    pass


class PullResponse(SQLModel):
    records: list[dict[str, Any]]
    has_more: bool
    next_since: datetime | None


class SyncStatusEntry(SQLModel):
    entity_name: str
    last_push_at: datetime | None
    last_pull_at: datetime | None
