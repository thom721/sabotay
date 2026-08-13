import uuid
from datetime import datetime
from decimal import Decimal
from enum import StrEnum

from sqlmodel import Field, SQLModel

from app.core.dt_utils import now_local


class StatutEntreprise(StrEnum):
    ESSAI = "essai"
    ACTIF = "actif"
    SUSPENDU = "suspendu"


class Entreprise(SQLModel, table=True):
    __tablename__ = "entreprises"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    nom: str = Field(index=True)
    devise: str = Field(default="HTG")
    fuseau_horaire: str = Field(default="America/Port-au-Prince")
    statut: StatutEntreprise = Field(default=StatutEntreprise.ESSAI)
    adresse: str | None = Field(default=None)
    telephone_contact: str | None = Field(default=None)
    # Préférence de largeur de papier pour une future fonctionnalité d'impression
    # de reçus (imprimante thermique). Valeurs attendues : "58mm" ou "80mm".
    format_recu: str = Field(default="80mm")
    # Texte personnalisé imprimé en bas du reçu de collecte (ex: "Merci de votre
    # confiance"). Configuré séparément des informations générales de l'entreprise.
    texte_bas_recu: str | None = Field(default=None)
    # Frais fixe appliqué à chaque retrait — configuré côté web (pas d'écran
    # de config web dans ce repo pour l'instant, mais le mobile doit déjà
    # respecter cette valeur sans pouvoir la modifier).
    frais_retrait: Decimal = Field(default=Decimal("0"), max_digits=12, decimal_places=2)
    date_creation: datetime = Field(default_factory=now_local)
    # Watermark de synchronisation (Phase 2) — mis à jour automatiquement par
    # SQLAlchemy à chaque UPDATE (onupdate), jamais réglé manuellement dans
    # les endpoints.
    updated_at: datetime = Field(
        default_factory=now_local,
        sa_column_kwargs={"onupdate": now_local},
    )
