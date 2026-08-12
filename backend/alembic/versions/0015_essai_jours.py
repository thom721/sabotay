"""platform config: configurable trial duration (essai_jours)

Revision ID: 0015
Revises: 0014
Create Date: 2026-08-06

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0015"
down_revision: Union[str, None] = "0014"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "platform_config",
        sa.Column("essai_jours", sa.Integer(), nullable=False, server_default="14"),
    )


def downgrade() -> None:
    op.drop_column("platform_config", "essai_jours")
