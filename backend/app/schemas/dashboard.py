from datetime import date
from decimal import Decimal

from sqlmodel import SQLModel

from app.schemas.transaction import TransactionRead


class VelociteJournaliereRead(SQLModel):
    date: date
    montant_collecte: Decimal


class DashboardStatistiquesRead(SQLModel):
    montant_collecte_mois: Decimal
    nb_transactions_payees_mois: int
    velocite_7_jours: list[VelociteJournaliereRead]
    transactions_recentes: list[TransactionRead]


class PointSerieTemporelleRead(SQLModel):
    label: str
    montant_collecte: Decimal
    montant_retrait: Decimal
    nb_nouveaux_clients: int


class SerieTemporelleRead(SQLModel):
    points: list[PointSerieTemporelleRead]
