from datetime import date
from decimal import Decimal

from sqlmodel import SQLModel

from app.models.compte_sabotay import StatutCompte


class CompteSabotayCreate(SQLModel):
    client_id: str
    montant_journalier: Decimal
    date_debut: date
    duree_jours: int


class CompteSabotayRead(SQLModel):
    id: str
    entreprise_id: str
    client_id: str
    numero_compte: str
    montant_journalier: Decimal
    date_debut: date
    duree_jours: int
    date_fin_prevue: date
    montant_total_attendu: Decimal
    statut: StatutCompte


class CompteSabotaySolde(SQLModel):
    compte_id: str
    montant_total_attendu: Decimal
    montant_collecte: Decimal
    montant_retire: Decimal
    solde_restant: Decimal
    solde_disponible: Decimal
    dette: Decimal
    jours_manques: int


class CompteSabotayAvecSolde(CompteSabotayRead):
    """`CompteSabotayRead` enrichi du solde — utilisé par `GET /comptes`
    (registre tenant-wide pour le cache offline mobile, Epic 6) afin
    d'éviter un appel `/comptes/{id}/solde` par compte lors d'un
    rafraîchissement de cache : le solde est calculé en une seule requête
    groupée plutôt qu'une par compte."""

    montant_collecte: Decimal
    montant_retire: Decimal
    solde_restant: Decimal
    solde_disponible: Decimal
    dette: Decimal
    jours_manques: int


class CompteSabotayPage(SQLModel):
    items: list[CompteSabotayAvecSolde]
    total: int
