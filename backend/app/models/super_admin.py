from datetime import datetime, timezone

from sqlmodel import Field, SQLModel


class SuperAdmin(SQLModel, table=True):
    __tablename__ = "super_admins"

    id: int | None = Field(default=None, primary_key=True)
    nom: str
    email: str = Field(unique=True, index=True)
    hashed_password: str
    date_creation: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    derniere_connexion: datetime | None = Field(default=None)
    statut: str = Field(default="actif")
