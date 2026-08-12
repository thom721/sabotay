from datetime import date
from decimal import Decimal

from sqlmodel import SQLModel

from app.models.compte_sabotay import StatutCompte


class CompteSabotayCreate(SQLModel):
    client_id: int
    montant_journalier: Decimal
    date_debut: date
    duree_jours: int


class CompteSabotayRead(SQLModel):
    id: int
    entreprise_id: int
    client_id: int
    numero_compte: str
    montant_journalier: Decimal
    date_debut: date
    duree_jours: int
    date_fin_prevue: date
    montant_total_attendu: Decimal
    statut: StatutCompte


class CompteSabotaySolde(SQLModel):
    compte_id: int
    montant_total_attendu: Decimal
    montant_collecte: Decimal
    montant_retire: Decimal
    solde_restant: Decimal
    solde_disponible: Decimal
    dette: Decimal
    jours_manques: int
