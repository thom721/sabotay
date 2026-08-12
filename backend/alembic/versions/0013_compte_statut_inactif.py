"""compte sabotay statut inactif

Revision ID: 0013
Revises: 0012
Create Date: 2026-08-05

"""
from typing import Sequence, Union

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0013"
down_revision: Union[str, None] = "0012"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Nouveau statut atteint quand un retrait ramène le solde disponible d'un
    # compte à 0 (crud.transaction.create_retrait) — le compte reste visible
    # avec tout son historique, seul son statut change.
    op.execute("ALTER TYPE statutcompte ADD VALUE 'INACTIF'")


def downgrade() -> None:
    # Postgres ne permet pas de retirer une valeur d'un type ENUM sans
    # recréer le type entièrement — no-op, cohérent avec le fait qu'aucune
    # ligne ne devrait porter ce statut avant que cette migration ne soit
    # appliquée à nouveau.
    pass
