"""transactions : numéro de reçu lisible (numero)

Revision ID: 0028
Revises: 0027
Create Date: 2026-08-17

Remplace l'UUID technique (`transaction.id`) affiché tel quel sur les reçus
jusqu'ici (voir EPICS.md, Epic 3 — "effet cosmétique noté, pas corrigé") par
un numéro lisible, horodaté à la milliseconde ("TR-20260817143022137") — pas
de compteur séquentiel par tenant (pas de verrou/course à gérer, contraire-
ment à `comptes_sabotay.numero_compte`). Les lignes déjà existantes sont
rétro-remplies depuis leur propre `cree_le`, pas une valeur unique partagée.
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0028"
down_revision: Union[str, None] = "0027"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("transactions", sa.Column("numero", sa.String(), nullable=True))
    op.execute(
        "UPDATE transactions SET numero = 'TR-' || to_char(cree_le, 'YYYYMMDDHH24MISSMS') "
        "WHERE numero IS NULL"
    )
    op.alter_column("transactions", "numero", nullable=False)
    op.create_index(op.f("ix_transactions_numero"), "transactions", ["numero"])


def downgrade() -> None:
    op.drop_index(op.f("ix_transactions_numero"), table_name="transactions")
    op.drop_column("transactions", "numero")
