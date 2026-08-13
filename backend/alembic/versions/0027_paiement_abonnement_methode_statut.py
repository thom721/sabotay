"""paiements_abonnement : méthode (moncash/espèces) et statut de confirmation

Revision ID: 0027
Revises: 0026
Create Date: 2026-08-13

Ajoute methode ("moncash"|"especes") et statut ("confirme"|"en_attente"|
"rejete") — support du paiement en espèces (même pattern que pos_api
BillingPayment.method/status) : une déclaration espèces reste en_attente
jusqu'à confirmation superadmin. Toutes les lignes déjà existantes sont des
paiements MonCash déjà confirmés (server_default couvre le backfill).
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0027"
down_revision: Union[str, None] = "0026"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "paiements_abonnement",
        sa.Column("methode", sa.String(), nullable=False, server_default="moncash"),
    )
    op.add_column(
        "paiements_abonnement",
        sa.Column("statut", sa.String(), nullable=False, server_default="confirme"),
    )


def downgrade() -> None:
    op.drop_column("paiements_abonnement", "statut")
    op.drop_column("paiements_abonnement", "methode")
