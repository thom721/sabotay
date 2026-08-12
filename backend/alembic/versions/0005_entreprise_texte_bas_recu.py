"""entreprise receipt footer text

Revision ID: 0005
Revises: 0004
Create Date: 2026-08-01

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0005"
down_revision: Union[str, None] = "0004"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "entreprises", sa.Column("texte_bas_recu", sa.String(), nullable=True)
    )


def downgrade() -> None:
    op.drop_column("entreprises", "texte_bas_recu")
