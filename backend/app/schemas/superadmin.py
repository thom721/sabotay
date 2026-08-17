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
    id: str
    nom: str
    devise: str
    statut: str
    date_creation: datetime
    abonnement: AbonnementSuperAdminRead | None
    nb_employes: int
    nb_clients: int
    # Vrai dès la première synchronisation réussie d'un poste bureau — voir
    # Entreprise.est_installe. Un super-admin peut le repasser à False
    # (POST /superadmin/entreprises/{id}/reinitialiser-installation).
    est_installe: bool


class UtilisateurSuperAdminRead(SQLModel):
    id: str
    nom: str
    prenom: str | None
    email: str | None
    role: RoleUtilisateur
    statut: StatutUtilisateur
    derniere_connexion: datetime | None


class ClientSuperAdminRead(SQLModel):
    id: str
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
    id: str
    nom: str
    email: str
    statut: str
    date_creation: datetime
    derniere_connexion: datetime | None


class SuperAdminCompteCreate(SQLModel):
    nom: str
    email: str
    password: str


class SuperAdminBootstrapStatut(SQLModel):
    necessaire: bool


class SuperAdminStatutUpdate(SQLModel):
    statut: str


class PlatformConfigRead(SQLModel):
    abonnement_montant_htg: int
    # Prix du PROCHAIN renouvellement, distinct du prix courant — None si
    # aucun changement de prix n'est annoncé (voir PlatformConfig).
    abonnement_renouvellement_htg: int | None
    essai_jours: int
    smtp_host: str | None
    smtp_port: int
    smtp_user: str | None
    # Jamais le mot de passe réel — seulement s'il est défini ou non (voir
    # read_platform_config, qui construit ce champ explicitement).
    smtp_password_defini: bool
    smtp_from_email: str | None


class PlatformConfigUpdate(SQLModel):
    # Tous optionnels — PATCH partiel, un onglet (Abonnement, Email) peut
    # envoyer uniquement ses propres champs sans écraser les autres (voir
    # crud.platform_config.update, exclude_unset).
    abonnement_montant_htg: int | None = None
    abonnement_renouvellement_htg: int | None = None
    essai_jours: int | None = None
    smtp_host: str | None = None
    smtp_port: int | None = None
    smtp_user: str | None = None
    smtp_password: str | None = None
    smtp_from_email: str | None = None
