import uuid
from datetime import date, datetime
from enum import StrEnum

from sqlmodel import Field, SQLModel

from app.core.dt_utils import now_local


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

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    entreprise_id: str = Field(foreign_key="entreprises.id", unique=True, index=True)
    plan: PlanAbonnement = Field(default=PlanAbonnement.STARTER)
    date_debut: date
    date_renouvellement: date | None = Field(default=None)
    statut: StatutAbonnement = Field(default=StatutAbonnement.ESSAI)
    date_creation: datetime = Field(default_factory=now_local)
    montant: int = Field(default=100)
    moncash_order_id: str | None = Field(default=None)
    moncash_transaction_id: str | None = Field(default=None)
    date_paiement: datetime | None = Field(default=None)
