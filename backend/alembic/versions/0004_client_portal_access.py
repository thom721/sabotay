"""client portal access fields

Revision ID: 0004
Revises: 0003
Create Date: 2026-08-01

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0004"
down_revision: Union[str, None] = "0003"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "clients", sa.Column("prenom", sa.String(), nullable=True)
    )
    op.execute("UPDATE clients SET prenom = '' WHERE prenom IS NULL")
    op.alter_column("clients", "prenom", nullable=False)
    op.add_column("clients", sa.Column("date_naissance", sa.Date(), nullable=True))
    op.add_column("clients", sa.Column("nif_cin", sa.String(), nullable=True))
    op.add_column("clients", sa.Column("email", sa.String(), nullable=True))
    op.create_index("ix_clients_email", "clients", ["email"])
    op.add_column("clients", sa.Column("hashed_password", sa.String(), nullable=True))
    op.add_column(
        "clients",
        sa.Column(
            "doit_changer_mot_de_passe",
            sa.Boolean(),
            nullable=False,
            server_default="false",
        ),
    )
    op.add_column("clients", sa.Column("heritier_nom", sa.String(), nullable=True))
    op.add_column("clients", sa.Column("heritier_prenom", sa.String(), nullable=True))
    op.add_column("clients", sa.Column("heritier_adresse", sa.String(), nullable=True))
    op.add_column("clients", sa.Column("heritier_telephone", sa.String(), nullable=True))


def downgrade() -> None:
    op.drop_column("clients", "heritier_telephone")
    op.drop_column("clients", "heritier_adresse")
    op.drop_column("clients", "heritier_prenom")
    op.drop_column("clients", "heritier_nom")
    op.drop_column("clients", "doit_changer_mot_de_passe")
    op.drop_column("clients", "hashed_password")
    op.drop_index("ix_clients_email", table_name="clients")
    op.drop_column("clients", "email")
    op.drop_column("clients", "nif_cin")
    op.drop_column("clients", "date_naissance")
    op.drop_column("clients", "prenom")
