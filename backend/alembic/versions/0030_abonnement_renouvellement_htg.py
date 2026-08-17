"""platform_config : prix de renouvellement distinct

Revision ID: 0030
Revises: 0029
Create Date: 2026-08-17

Ajoute `abonnement_renouvellement_htg` (nullable) — prix appliqué au
PROCHAIN renouvellement, distinct de `abonnement_montant_htg`, pour pouvoir
annoncer un changement de prix à l'avance sur la page Abonnement du client
avant qu'il ne soit effectivement facturé. None = pas de changement annoncé.
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0030"
down_revision: Union[str, None] = "0029"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "platform_config",
        sa.Column("abonnement_renouvellement_htg", sa.Integer(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("platform_config", "abonnement_renouvellement_htg")
