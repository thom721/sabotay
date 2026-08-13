"""paiements_abonnement : identifiant de l'utilisateur qui a confirmé le paiement

Revision ID: 0026
Revises: 0025
Create Date: 2026-08-13

Ajoute paye_par_id/paye_par_nom — même pattern que
Transaction.collecte_par_id/collecte_par_nom (dénormalisé, GET /utilisateurs
étant réservé Admin/Manager). Nullable : les lignes déjà existantes n'ont pas
cette information.
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0026"
down_revision: Union[str, None] = "0025"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "paiements_abonnement",
        sa.Column("paye_par_id", sa.String(36), sa.ForeignKey("utilisateurs.id"), nullable=True),
    )
    op.add_column(
        "paiements_abonnement", sa.Column("paye_par_nom", sa.String(), nullable=True)
    )


def downgrade() -> None:
    op.drop_column("paiements_abonnement", "paye_par_nom")
    op.drop_column("paiements_abonnement", "paye_par_id")
