"""platform config (global abonnement price)

Revision ID: 0014
Revises: 0013
Create Date: 2026-08-06

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0014"
down_revision: Union[str, None] = "0013"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "platform_config",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "abonnement_montant_htg",
            sa.Integer(),
            nullable=False,
            server_default="100",
        ),
    )
    # Singleton : une seule ligne, toujours présente, pour que
    # crud.platform_config.get() n'ait jamais à gérer une table vide.
    op.execute("INSERT INTO platform_config (abonnement_montant_htg) VALUES (100)")


def downgrade() -> None:
    op.drop_table("platform_config")
