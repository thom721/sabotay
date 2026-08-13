from datetime import date, datetime

from sqlmodel import SQLModel

from app.models.client import StatutClient


class ClientCreate(SQLModel):
    nom: str
    prenom: str
    telephone: str
    adresse: str | None = None
    date_naissance: date | None = None
    nif_cin: str | None = None
    photo_url: str | None = None
    agent_assigne_id: str | None = None
    email: str | None = None
    heritier_nom: str | None = None
    heritier_prenom: str | None = None
    heritier_adresse: str | None = None
    heritier_telephone: str | None = None


class ClientAssignAgent(SQLModel):
    agent_assigne_id: str | None


class ClientRead(SQLModel):
    id: str
    entreprise_id: str
    nom: str
    prenom: str
    telephone: str
    adresse: str | None
    date_naissance: date | None
    nif_cin: str | None
    photo_url: str | None
    agent_assigne_id: str | None
    email: str | None
    doit_changer_mot_de_passe: bool
    heritier_nom: str | None
    heritier_prenom: str | None
    heritier_adresse: str | None
    heritier_telephone: str | None
    statut: StatutClient
    derniere_connexion: datetime | None
