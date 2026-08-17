from datetime import date, datetime
from decimal import Decimal

from sqlmodel import SQLModel

from app.models.transaction import TypeTransaction


class TransactionCreate(SQLModel):
    """Une collecte : le montant n'est jamais envoyé par le client, il est
    calculé côté serveur (nb_jours * compte.montant_journalier) pour qu'il
    ne soit pas modifiable, même en contournant l'UI."""

    compte_id: str
    date: date
    nb_jours: int = 1


class RetraitCreate(SQLModel):
    compte_id: str
    date: date
    montant: Decimal


class TransactionRead(SQLModel):
    id: str
    numero: str
    entreprise_id: str
    compte_id: str
    date: date
    montant: Decimal
    type: TypeTransaction
    nb_jours: int | None
    frais: Decimal | None
    collecte_par_id: str
    collecte_par_nom: str
    cree_le: datetime


class TransactionRegistreItem(TransactionRead):
    """Une ligne du registre de transactions (`GET /transactions`) — mêmes
    champs que `TransactionRead`, enrichis du nom du client et du numéro de
    compte (résolus via jointure) pour permettre la recherche libre sans que
    l'appelant ait à résoudre `compte_id` lui-même."""

    client_nom: str
    compte_numero: str


class RapportRead(SQLModel):
    date_debut: date
    date_fin: date
    total_collecte: Decimal
    total_retrait: Decimal
    nb_transactions: int
    # TransactionRegistreItem (pas TransactionRead) : chaque ligne du rapport
    # doit être imprimable individuellement (reçu), qui a besoin du nom du
    # client et du numéro de compte — voir crud/transaction.py::list_for_periode.
    transactions: list[TransactionRegistreItem]


class TransactionRegistrePage(SQLModel):
    items: list[TransactionRegistreItem]
    total: int
