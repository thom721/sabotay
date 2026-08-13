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
    # Qui a déclenché la confirmation du paiement (toujours un Admin, voir
    # abonnement.py::verifier_abonnement/marquer_paye_dev) — dénormalisé
    # comme Transaction.collecte_par_nom, même raisonnement (GET
    # /utilisateurs est réservé Admin/Manager). Nullable : un futur webhook
    # MonCash entièrement automatisé n'aurait pas d'utilisateur courant.
    paye_par_id: str | None = Field(default=None, foreign_key="utilisateurs.id")
    paye_par_nom: str | None = Field(default=None)
