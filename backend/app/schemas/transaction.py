from datetime import date, datetime
from decimal import Decimal

from sqlmodel import SQLModel

from app.models.transaction import TypeTransaction


class TransactionCreate(SQLModel):
    """Une collecte : le montant n'est jamais envoyé par le client, il est
    calculé côté serveur (nb_jours * compte.montant_journalier) pour qu'il
    ne soit pas modifiable, même en contournant l'UI."""

    compte_id: int
    date: date
    nb_jours: int = 1


class RetraitCreate(SQLModel):
    compte_id: int
    date: date
    montant: Decimal


class TransactionRead(SQLModel):
    id: int
    entreprise_id: int
    compte_id: int
    date: date
    montant: Decimal
    type: TypeTransaction
    nb_jours: int | None
    frais: Decimal | None
    collecte_par_id: int
    collecte_par_nom: str
    cree_le: datetime


class RapportRead(SQLModel):
    date_debut: date
    date_fin: date
    total_collecte: Decimal
    total_retrait: Decimal
    nb_transactions: int
    transactions: list[TransactionRead]
