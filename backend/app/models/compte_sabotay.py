from datetime import date, datetime, timezone
from decimal import Decimal
from enum import StrEnum

from sqlmodel import Field, SQLModel, UniqueConstraint


class StatutCompte(StrEnum):
    ACTIF = "actif"
    EN_RETARD = "en_retard"
    COMPLETE = "complete"
    ANNULE = "annule"
    INACTIF = "inactif"


class CompteSabotay(SQLModel, table=True):
    __tablename__ = "comptes_sabotay"
    __table_args__ = (
        UniqueConstraint("entreprise_id", "numero_compte", name="uq_comptes_sabotay_entreprise_numero"),
    )

    id: int | None = Field(default=None, primary_key=True)
    # Dénormalisé depuis client_id pour permettre un filtrage tenant_id direct
    # sur cette table sans jointure (isolation multi-tenant systématique).
    entreprise_id: int = Field(foreign_key="entreprises.id", index=True)
    client_id: int = Field(foreign_key="clients.id", index=True)
    # Format "SB-000001", séquentiel par entreprise (pas global) — généré à la
    # création (crud.compte_sabotay.create), sert d'identifiant de recherche
    # pour la collecte (tous rôles) au lieu de l'id numérique interne.
    numero_compte: str = Field(index=True)

    montant_journalier: Decimal = Field(max_digits=12, decimal_places=2)
    date_debut: date
    duree_jours: int
    date_fin_prevue: date
    montant_total_attendu: Decimal = Field(max_digits=14, decimal_places=2)

    statut: StatutCompte = Field(default=StatutCompte.ACTIF)
    date_creation: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
