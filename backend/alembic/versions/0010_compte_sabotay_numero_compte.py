"""comptes_sabotay numero_compte column

Revision ID: 0010
Revises: 0009
Create Date: 2026-08-03

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0010"
down_revision: Union[str, None] = "0009"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("comptes_sabotay", sa.Column("numero_compte", sa.String(), nullable=True))
    op.execute(
        """
        WITH numbered AS (
            SELECT id, entreprise_id,
                   ROW_NUMBER() OVER (PARTITION BY entreprise_id ORDER BY id) AS rang
            FROM comptes_sabotay
        )
        UPDATE comptes_sabotay
        SET numero_compte = 'SB-' || LPAD(numbered.rang::text, 6, '0')
        FROM numbered
        WHERE comptes_sabotay.id = numbered.id
        """
    )
    op.alter_column("comptes_sabotay", "numero_compte", nullable=False)
    op.create_index(
        "ix_comptes_sabotay_numero_compte", "comptes_sabotay", ["numero_compte"]
    )
    op.create_unique_constraint(
        "uq_comptes_sabotay_entreprise_numero",
        "comptes_sabotay",
        ["entreprise_id", "numero_compte"],
    )


def downgrade() -> None:
    op.drop_constraint("uq_comptes_sabotay_entreprise_numero", "comptes_sabotay", type_="unique")
    op.drop_index("ix_comptes_sabotay_numero_compte", table_name="comptes_sabotay")
    op.drop_column("comptes_sabotay", "numero_compte")
