"""entreprise profile fields

Revision ID: 0003
Revises: 0002
Create Date: 2026-08-01

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0003"
down_revision: Union[str, None] = "0002"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("entreprises", sa.Column("adresse", sa.String(), nullable=True))
    op.add_column(
        "entreprises", sa.Column("telephone_contact", sa.String(), nullable=True)
    )
    op.add_column(
        "entreprises",
        sa.Column(
            "format_recu", sa.String(), nullable=False, server_default="80mm"
        ),
    )


def downgrade() -> None:
    op.drop_column("entreprises", "format_recu")
    op.drop_column("entreprises", "telephone_contact")
    op.drop_column("entreprises", "adresse")
