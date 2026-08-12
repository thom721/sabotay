"""transactions type/nb_jours/frais, entreprises frais_retrait

Revision ID: 0012
Revises: 0011
Create Date: 2026-08-04

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0012"
down_revision: Union[str, None] = "0011"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # "manqué" devient une valeur calculée (jours écoulés sans collecte), plus
    # jamais stockée — les anciennes lignes MANQUE (données de dev) n'ont pas
    # d'équivalent dans le nouveau modèle.
    op.execute("DELETE FROM transactions WHERE statut = 'MANQUE'")

    typetransaction = sa.Enum("COLLECTE", "RETRAIT", name="typetransaction")
    typetransaction.create(op.get_bind())

    op.add_column("transactions", sa.Column("type", typetransaction, nullable=True))
    op.execute("UPDATE transactions SET type = 'COLLECTE' WHERE statut = 'PAYE'")
    op.alter_column("transactions", "type", nullable=False)

    op.drop_column("transactions", "statut")
    sa.Enum(name="statuttransaction").drop(op.get_bind(), checkfirst=True)

    op.add_column("transactions", sa.Column("nb_jours", sa.Integer(), nullable=True))
    op.execute("UPDATE transactions SET nb_jours = 1 WHERE type = 'COLLECTE'")

    op.add_column(
        "transactions", sa.Column("frais", sa.Numeric(12, 2), nullable=True)
    )

    op.add_column(
        "entreprises",
        sa.Column(
            "frais_retrait", sa.Numeric(12, 2), nullable=False, server_default="0"
        ),
    )
    op.alter_column("entreprises", "frais_retrait", server_default=None)


def downgrade() -> None:
    op.drop_column("entreprises", "frais_retrait")
    op.drop_column("transactions", "frais")
    op.drop_column("transactions", "nb_jours")

    statuttransaction = sa.Enum("PAYE", "MANQUE", name="statuttransaction")
    statuttransaction.create(op.get_bind())
    op.add_column("transactions", sa.Column("statut", statuttransaction, nullable=True))
    op.execute("UPDATE transactions SET statut = 'PAYE' WHERE type = 'COLLECTE'")
    op.alter_column("transactions", "statut", nullable=False)

    op.drop_column("transactions", "type")
    sa.Enum(name="typetransaction").drop(op.get_bind(), checkfirst=True)
