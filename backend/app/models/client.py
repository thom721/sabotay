from datetime import date, datetime, timezone
from enum import StrEnum

from sqlmodel import Field, SQLModel


class StatutClient(StrEnum):
    ACTIF = "actif"
    INACTIF = "inactif"


class Client(SQLModel, table=True):
    __tablename__ = "clients"

    id: int | None = Field(default=None, primary_key=True)
    entreprise_id: int = Field(foreign_key="entreprises.id", index=True)
    nom: str
    prenom: str
    telephone: str = Field(index=True)
    adresse: str | None = Field(default=None)
    date_naissance: date | None = Field(default=None)
    nif_cin: str | None = Field(default=None)
    photo_url: str | None = Field(default=None)
    agent_assigne_id: int | None = Field(default=None, foreign_key="utilisateurs.id")
    code_acces: str | None = Field(default=None, description="Code d'accès à l'espace client")
    email: str | None = Field(default=None, index=True)
    hashed_password: str | None = Field(default=None)
    doit_changer_mot_de_passe: bool = Field(default=False)
    heritier_nom: str | None = Field(default=None)
    heritier_prenom: str | None = Field(default=None)
    heritier_adresse: str | None = Field(default=None)
    heritier_telephone: str | None = Field(default=None)
    statut: StatutClient = Field(default=StatutClient.ACTIF)
    date_creation: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    derniere_connexion: datetime | None = Field(default=None)
