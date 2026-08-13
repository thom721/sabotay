import uuid
from datetime import datetime

from sqlmodel import Field, SQLModel, UniqueConstraint


class SyncState(SQLModel, table=True):
    """Curseur de synchronisation par (device, entité).

    Même table utilisée des deux côtés : côté cloud, un enregistrement par
    device réel connecté (`device_id` = celui du JWT de sync) — le cloud
    sert potentiellement plusieurs installations locales. Côté local,
    `device_id` vaut toujours la constante "self" (un seul cloud en face,
    pas besoin de distinguer)."""

    __tablename__ = "sync_state"
    __table_args__ = (
        UniqueConstraint("device_id", "entity_name", name="uq_sync_state_device_entity"),
    )

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    device_id: str = Field(index=True)
    # Dénormalisé depuis le jeton de sync — permet à un Admin de consulter
    # GET /sync/status (staff normal, pas de jeton de sync) filtré sur son
    # propre tenant sans avoir à connaître le(s) device_id concerné(s).
    entreprise_id: str = Field(foreign_key="entreprises.id", index=True)
    entity_name: str
    last_push_at: datetime | None = Field(default=None)
    last_pull_at: datetime | None = Field(default=None)
