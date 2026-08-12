from datetime import datetime, timezone
from decimal import Decimal
from enum import StrEnum

from sqlmodel import Field, SQLModel


class StatutEntreprise(StrEnum):
    ESSAI = "essai"
    ACTIF = "actif"
    SUSPENDU = "suspendu"


class Entreprise(SQLModel, table=True):
    __tablename__ = "entreprises"

    id: int | None = Field(default=None, primary_key=True)
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
    date_creation: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
