import uuid
from datetime import date, datetime
from decimal import Decimal
from enum import StrEnum

from sqlmodel import Field, SQLModel

from app.core.dt_utils import now_local


class TypeTransaction(StrEnum):
    COLLECTE = "collecte"
    RETRAIT = "retrait"


def _generate_numero() -> str:
    """Numéro de reçu lisible, ex. "TR-20260817143022137" — préféré à un
    compteur séquentiel par tenant (pas de verrou/course à gérer, contraire-
    ment à `CompteSabotay.numero_compte`) : timestamp à la milliseconde,
    collision pratiquement impossible même en cas de saisies concurrentes.
    Remplace l'UUID technique (`transaction.id`) affiché tel quel sur les
    reçus jusqu'ici (voir EPICS.md, Epic 3)."""
    horodatage = now_local()
    return f"TR-{horodatage:%Y%m%d%H%M%S}{horodatage.microsecond // 1000:03d}"


class Transaction(SQLModel, table=True):
    __tablename__ = "transactions"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    # Numéro affiché sur les reçus/rapports — voir _generate_numero(). Distinct
    # de `id` (clé technique, jamais montrée à l'utilisateur).
    numero: str = Field(default_factory=_generate_numero, index=True)
    # Dénormalisé depuis compte_id pour permettre un filtrage tenant_id direct
    # sur cette table sans jointure (isolation multi-tenant systématique).
    entreprise_id: str = Field(foreign_key="entreprises.id", index=True)
    compte_id: str = Field(foreign_key="comptes_sabotay.id", index=True)

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
    collecte_par_id: str = Field(foreign_key="utilisateurs.id")
    # Dénormalisé depuis collecte_par_id : un reçu réimprimé plus tard doit
    # afficher qui a collecté, mais GET /utilisateurs est réservé
    # Admin/Manager — un Agent ne peut pas résoudre le nom d'un collègue.
    collecte_par_nom: str
    cree_le: datetime = Field(default_factory=now_local)
    # Watermark de synchronisation (Phase 2) — mis à jour automatiquement par
    # SQLAlchemy à chaque UPDATE (onupdate), jamais réglé manuellement dans
    # les endpoints. Une transaction est rarement modifiée après coup, mais
    # la colonne existe pour rester cohérente avec le registre de sync.
    updated_at: datetime = Field(
        default_factory=now_local,
        sa_column_kwargs={"onupdate": now_local},
    )
