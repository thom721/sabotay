from datetime import date, datetime
from decimal import Decimal

from sqlmodel import SQLModel

from app.models.abonnement import PlanAbonnement, StatutAbonnement
from app.models.client import StatutClient
from app.models.utilisateur import RoleUtilisateur, StatutUtilisateur


class AbonnementSuperAdminRead(SQLModel):
    plan: PlanAbonnement
    statut: StatutAbonnement
    date_renouvellement: date | None
    montant: int


class EntrepriseSuperAdminRead(SQLModel):
    id: int
    nom: str
    devise: str
    statut: str
    date_creation: datetime
    abonnement: AbonnementSuperAdminRead | None
    nb_employes: int
    nb_clients: int


class UtilisateurSuperAdminRead(SQLModel):
    id: int
    nom: str
    prenom: str | None
    email: str | None
    role: RoleUtilisateur
    statut: StatutUtilisateur
    derniere_connexion: datetime | None


class ClientSuperAdminRead(SQLModel):
    id: int
    nom: str
    prenom: str
    telephone: str
    email: str | None
    statut: StatutClient
    derniere_connexion: datetime | None


class EntrepriseSuperAdminDetailRead(EntrepriseSuperAdminRead):
    utilisateurs: list[UtilisateurSuperAdminRead]
    clients: list[ClientSuperAdminRead]


class StatistiquesSuperAdminRead(SQLModel):
    nb_entreprises_total: int
    nb_entreprises_abonnement_actif: int
    nb_clients_total: int
    nb_employes_total: int
    montant_total_collecte: Decimal
    montant_abonnements_collecte: int


class SuperAdminCompteRead(SQLModel):
    id: int
    nom: str
    email: str
    statut: str
    date_creation: datetime
    derniere_connexion: datetime | None


class SuperAdminCompteCreate(SQLModel):
    nom: str
    email: str
    password: str


class SuperAdminStatutUpdate(SQLModel):
    statut: str


class PlatformConfigRead(SQLModel):
    abonnement_montant_htg: int
    essai_jours: int


class PlatformConfigUpdate(SQLModel):
    abonnement_montant_htg: int
    essai_jours: int
