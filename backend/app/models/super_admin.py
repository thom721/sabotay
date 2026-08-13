import uuid
from datetime import datetime

from sqlmodel import Field, SQLModel

from app.core.dt_utils import now_local


class SuperAdmin(SQLModel, table=True):
    __tablename__ = "super_admins"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    nom: str
    email: str = Field(unique=True, index=True)
    hashed_password: str
    date_creation: datetime = Field(default_factory=now_local)
    derniere_connexion: datetime | None = Field(default=None)
    statut: str = Field(default="actif")
