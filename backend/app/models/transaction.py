from datetime import date, datetime, timezone
from decimal import Decimal
from enum import StrEnum

from sqlmodel import Field, SQLModel


class TypeTransaction(StrEnum):
    COLLECTE = "collecte"
    RETRAIT = "retrait"


class Transaction(SQLModel, table=True):
    __tablename__ = "transactions"

    id: int | None = Field(default=None, primary_key=True)
    # Dénormalisé depuis compte_id pour permettre un filtrage tenant_id direct
    # sur cette table sans jointure (isolation multi-tenant systématique).
    entreprise_id: int = Field(foreign_key="entreprises.id", index=True)
    compte_id: int = Field(foreign_key="comptes_sabotay.id", index=True)

    date: date
    montant: Decimal = Field(max_digits=12, decimal_places=2)
    type: TypeTransaction
    # Nombre de jours couverts par ce paiement (uniquement type=COLLECTE) —
    # un agent peut régler plusieurs jours manqués d'un coup ; montant =
    # nb_jours * compte.montant_journalier, toujours calculé côté serveur
    # (jamais saisi par le client de l'API).
    nb_jours: int | None = Field(default=None)
    # Frais appliqué au retrait (uniquement type=RETRAIT), copié depuis
    # Entreprise.frais_retrait au moment du retrait pour garder une trace
    # même si la configuration change ensuite.
    frais: Decimal | None = Field(default=None, max_digits=12, decimal_places=2)
    collecte_par_id: int = Field(foreign_key="utilisateurs.id")
    # Dénormalisé depuis collecte_par_id : un reçu réimprimé plus tard doit
    # afficher qui a collecté, mais GET /utilisateurs est réservé
    # Admin/Manager — un Agent ne peut pas résoudre le nom d'un collègue.
    collecte_par_nom: str
    cree_le: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
