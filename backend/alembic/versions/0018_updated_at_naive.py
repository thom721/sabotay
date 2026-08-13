"""updated_at : colonnes naïves (sans fuseau) — même choix que pos_api

Revision ID: 0018
Revises: 0017
Create Date: 2026-08-12

Les colonnes updated_at (watermarks de sync) passent de TIMESTAMP WITH TIME
ZONE à TIMESTAMP WITHOUT TIME ZONE. SQLite (mode local) ne préserve pas le
fuseau horaire aussi strictement que Postgres — comparer un datetime aware
et un naïf lève TypeError. En restant naïf partout (toujours UTC en
interne, jamais réattaché), le problème disparaît structurellement plutôt
que d'être corrigé au cas par cas dans le code de synchronisation.
"""
from typing import Sequence, Union

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0018"
down_revision: Union[str, None] = "0017"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

_TABLES = ["entreprises", "utilisateurs", "clients", "comptes_sabotay", "transactions"]


def upgrade() -> None:
    for table in _TABLES:
        op.execute(
            f"ALTER TABLE {table} ALTER COLUMN updated_at TYPE TIMESTAMP "
            f"USING updated_at AT TIME ZONE 'UTC'"
        )


def downgrade() -> None:
    for table in _TABLES:
        op.execute(
            f"ALTER TABLE {table} ALTER COLUMN updated_at TYPE TIMESTAMPTZ "
            f"USING updated_at AT TIME ZONE 'UTC'"
        )
