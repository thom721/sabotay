"""transactions collecte_par_nom column

Revision ID: 0011
Revises: 0010
Create Date: 2026-08-04

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0011"
down_revision: Union[str, None] = "0010"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("transactions", sa.Column("collecte_par_nom", sa.String(), nullable=True))
    op.execute(
        """
        UPDATE transactions
        SET collecte_par_nom = utilisateurs.nom
        FROM utilisateurs
        WHERE utilisateurs.id = transactions.collecte_par_id
        """
    )
    op.alter_column("transactions", "collecte_par_nom", nullable=False)


def downgrade() -> None:
    op.drop_column("transactions", "collecte_par_nom")
