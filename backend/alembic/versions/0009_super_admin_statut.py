"""super_admins statut column

Revision ID: 0009
Revises: 0008
Create Date: 2026-08-02

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0009"
down_revision: Union[str, None] = "0008"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "super_admins",
        sa.Column("statut", sa.String(), nullable=False, server_default="actif"),
    )


def downgrade() -> None:
    op.drop_column("super_admins", "statut")
