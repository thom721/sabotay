from datetime import date, datetime, timezone
from enum import StrEnum

from sqlmodel import Field, SQLModel


class RoleUtilisateur(StrEnum):
    ADMIN = "admin"
    MANAGER = "manager"
    AGENT = "agent"


class StatutUtilisateur(StrEnum):
    ACTIF = "actif"
    INACTIF = "inactif"


class Utilisateur(SQLModel, table=True):
    __tablename__ = "utilisateurs"

    id: int | None = Field(default=None, primary_key=True)
    entreprise_id: int = Field(foreign_key="entreprises.id", index=True)
    nom: str
    prenom: str | None = Field(default=None)
    telephone: str = Field(index=True)
    email: str | None = Field(default=None, index=True)
    hashed_password: str
    doit_changer_mot_de_passe: bool = Field(default=False)
    date_naissance: date | None = Field(default=None)
    nif_cin: str | None = Field(default=None)
    adresse: str | None = Field(default=None)
    role: RoleUtilisateur
    statut: StatutUtilisateur = Field(default=StatutUtilisateur.ACTIF)
    date_creation: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    derniere_connexion: datetime | None = Field(default=None)
