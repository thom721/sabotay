import uuid
from datetime import date, datetime
from enum import StrEnum

from sqlmodel import Field, SQLModel

from app.core.dt_utils import now_local


class StatutClient(StrEnum):
    ACTIF = "actif"
    INACTIF = "inactif"


class Client(SQLModel, table=True):
    __tablename__ = "clients"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    entreprise_id: str = Field(foreign_key="entreprises.id", index=True)
    nom: str
    prenom: str
    telephone: str = Field(index=True)
    adresse: str | None = Field(default=None)
    date_naissance: date | None = Field(default=None)
    nif_cin: str | None = Field(default=None)
    photo_url: str | None = Field(default=None)
    agent_assigne_id: str | None = Field(default=None, foreign_key="utilisateurs.id")
    code_acces: str | None = Field(default=None, description="Code d'accès à l'espace client")
    email: str | None = Field(default=None, index=True)
    hashed_password: str | None = Field(default=None)
    doit_changer_mot_de_passe: bool = Field(default=False)
    heritier_nom: str | None = Field(default=None)
    heritier_prenom: str | None = Field(default=None)
    heritier_adresse: str | None = Field(default=None)
    heritier_telephone: str | None = Field(default=None)
    statut: StatutClient = Field(default=StatutClient.ACTIF)
    date_creation: datetime = Field(default_factory=now_local)
    derniere_connexion: datetime | None = Field(default=None)
    # Watermark de synchronisation (Phase 2) — mis à jour automatiquement par
    # SQLAlchemy à chaque UPDATE (onupdate), jamais réglé manuellement dans
    # les endpoints.
    updated_at: datetime = Field(
        default_factory=now_local,
        sa_column_kwargs={"onupdate": now_local},
    )
