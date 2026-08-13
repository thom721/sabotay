import uuid
from datetime import datetime

from sqlmodel import Field, SQLModel

from app.core.dt_utils import now_local


class PaiementAbonnement(SQLModel, table=True):
    __tablename__ = "paiements_abonnement"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    abonnement_id: str = Field(foreign_key="abonnements.id", index=True)
    # Dénormalisé depuis abonnement_id pour permettre un filtrage tenant_id
    # direct sans jointure (même pattern que Transaction.entreprise_id).
    entreprise_id: str = Field(foreign_key="entreprises.id", index=True)
    montant: int
    moncash_order_id: str | None = Field(default=None)
    moncash_transaction_id: str | None = Field(default=None)
    date_paiement: datetime = Field(default_factory=now_local)
