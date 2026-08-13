import uuid
from datetime import datetime
from enum import StrEnum

from sqlmodel import Field, SQLModel

from app.core.dt_utils import now_local


class CanalReset(StrEnum):
    SMS = "sms"
    EMAIL = "email"


class PasswordResetToken(SQLModel, table=True):
    __tablename__ = "password_reset_tokens"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    utilisateur_id: str = Field(foreign_key="utilisateurs.id", index=True)
    code_hash: str
    canal: CanalReset
    tentatives: int = Field(default=0)
    utilise: bool = Field(default=False)
    date_creation: datetime = Field(default_factory=now_local)
    date_expiration: datetime
