from datetime import datetime, timezone
from enum import StrEnum

from sqlmodel import Field, SQLModel


class CanalReset(StrEnum):
    SMS = "sms"
    EMAIL = "email"


class PasswordResetToken(SQLModel, table=True):
    __tablename__ = "password_reset_tokens"

    id: int | None = Field(default=None, primary_key=True)
    utilisateur_id: int = Field(foreign_key="utilisateurs.id", index=True)
    code_hash: str
    canal: CanalReset
    tentatives: int = Field(default=0)
    utilise: bool = Field(default=False)
    date_creation: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    date_expiration: datetime
