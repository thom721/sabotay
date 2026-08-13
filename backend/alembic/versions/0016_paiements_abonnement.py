"""paiements_abonnement: historique des paiements d'abonnement

Revision ID: 0016
Revises: 0015
Create Date: 2026-08-12

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0016"
down_revision: Union[str, None] = "0015"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "paiements_abonnement",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "abonnement_id",
            sa.Integer(),
            sa.ForeignKey("abonnements.id"),
            nullable=False,
        ),
        sa.Column(
            "entreprise_id",
            sa.Integer(),
            sa.ForeignKey("entreprises.id"),
            nullable=False,
        ),
        sa.Column("montant", sa.Integer(), nullable=False),
        sa.Column("moncash_order_id", sa.String(), nullable=True),
        sa.Column("moncash_transaction_id", sa.String(), nullable=True),
        sa.Column("date_paiement", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index(
        "ix_paiements_abonnement_abonnement_id",
        "paiements_abonnement",
        ["abonnement_id"],
    )
    op.create_index(
        "ix_paiements_abonnement_entreprise_id",
        "paiements_abonnement",
        ["entreprise_id"],
    )


def downgrade() -> None:
    op.drop_table("paiements_abonnement")
