"""abonnement moncash fields and derniere_connexion tracking

Revision ID: 0007
Revises: 0006
Create Date: 2026-08-01

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0007"
down_revision: Union[str, None] = "0006"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "abonnements",
        sa.Column("montant", sa.Integer(), nullable=False, server_default="100"),
    )
    op.add_column("abonnements", sa.Column("moncash_order_id", sa.String(), nullable=True))
    op.add_column(
        "abonnements", sa.Column("moncash_transaction_id", sa.String(), nullable=True)
    )
    op.add_column(
        "abonnements", sa.Column("date_paiement", sa.DateTime(timezone=True), nullable=True)
    )

    op.add_column(
        "utilisateurs",
        sa.Column("derniere_connexion", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "clients",
        sa.Column("derniere_connexion", sa.DateTime(timezone=True), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("clients", "derniere_connexion")
    op.drop_column("utilisateurs", "derniere_connexion")

    op.drop_column("abonnements", "date_paiement")
    op.drop_column("abonnements", "moncash_transaction_id")
    op.drop_column("abonnements", "moncash_order_id")
    op.drop_column("abonnements", "montant")
