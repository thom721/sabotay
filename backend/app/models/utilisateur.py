import uuid
from datetime import date, datetime
from enum import StrEnum

from sqlmodel import Field, SQLModel

from app.core.dt_utils import now_local


class RoleUtilisateur(StrEnum):
    ADMIN = "admin"
    MANAGER = "manager"
    AGENT = "agent"


class StatutUtilisateur(StrEnum):
    ACTIF = "actif"
    INACTIF = "inactif"


class Utilisateur(SQLModel, table=True):
    __tablename__ = "utilisateurs"

    # UUID généré à la construction de l'objet (jamais par une séquence DB) —
    # deux installations (cloud, poste local) ne peuvent jamais assigner le
    # même id, connectées ou non. Même choix que pos_api (UUIDBase).
    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    entreprise_id: str = Field(foreign_key="entreprises.id", index=True)
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
    date_creation: datetime = Field(default_factory=now_local)
    derniere_connexion: datetime | None = Field(default=None)
    # Watermark de synchronisation (Phase 2) — mis à jour automatiquement par
    # SQLAlchemy à chaque UPDATE (onupdate), jamais réglé manuellement dans
    # les endpoints.
    updated_at: datetime = Field(
        default_factory=now_local,
        sa_column_kwargs={"onupdate": now_local},
    )
