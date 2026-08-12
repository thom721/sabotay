from datetime import date, datetime, timezone
from enum import StrEnum

from sqlmodel import Field, SQLModel


class PlanAbonnement(StrEnum):
    STARTER = "starter"
    PRO = "pro"
    BUSINESS = "business"


class StatutAbonnement(StrEnum):
    ESSAI = "essai"
    ACTIF = "actif"
    SUSPENDU = "suspendu"
    ANNULE = "annule"


class Abonnement(SQLModel, table=True):
    __tablename__ = "abonnements"

    id: int | None = Field(default=None, primary_key=True)
    entreprise_id: int = Field(foreign_key="entreprises.id", unique=True, index=True)
    plan: PlanAbonnement = Field(default=PlanAbonnement.STARTER)
    date_debut: date
    date_renouvellement: date | None = Field(default=None)
    statut: StatutAbonnement = Field(default=StatutAbonnement.ESSAI)
    date_creation: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    montant: int = Field(default=100)
    moncash_order_id: str | None = Field(default=None)
    moncash_transaction_id: str | None = Field(default=None)
    date_paiement: datetime | None = Field(default=None)
