from datetime import date, datetime

from sqlmodel import SQLModel

from app.models.utilisateur import RoleUtilisateur, StatutUtilisateur


class UtilisateurCreate(SQLModel):
    """Invitation d'un employé par l'Admin Entreprise (PRD §8.2)."""

    nom: str
    prenom: str
    telephone: str
    email: str
    date_naissance: date | None = None
    nif_cin: str | None = None
    adresse: str | None = None
    role: RoleUtilisateur


class UtilisateurStatutUpdate(SQLModel):
    statut: StatutUtilisateur


class UtilisateurRoleUpdate(SQLModel):
    role: RoleUtilisateur


class UtilisateurRead(SQLModel):
    id: str
    entreprise_id: str
    nom: str
    prenom: str | None
    telephone: str
    email: str | None
    date_naissance: date | None
    nif_cin: str | None
    adresse: str | None
    doit_changer_mot_de_passe: bool
    role: RoleUtilisateur
    statut: StatutUtilisateur
    derniere_connexion: datetime | None
    # Présents uniquement juste après la création (voir crud/utilisateur.py)
    # — None sur toute lecture ultérieure de l'employé.
    email_envoye: bool | None = None
    mot_de_passe_temporaire: str | None = None
