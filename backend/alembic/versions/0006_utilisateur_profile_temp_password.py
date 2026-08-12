"""utilisateur profile fields and temp password flag

Revision ID: 0006
Revises: 0005
Create Date: 2026-08-01

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0006"
down_revision: Union[str, None] = "0005"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("utilisateurs", sa.Column("prenom", sa.String(), nullable=True))
    op.add_column("utilisateurs", sa.Column("date_naissance", sa.Date(), nullable=True))
    op.add_column("utilisateurs", sa.Column("nif_cin", sa.String(), nullable=True))
    op.add_column("utilisateurs", sa.Column("adresse", sa.String(), nullable=True))
    op.add_column(
        "utilisateurs",
        sa.Column(
            "doit_changer_mot_de_passe",
            sa.Boolean(),
            nullable=False,
            server_default="false",
        ),
    )


def downgrade() -> None:
    op.drop_column("utilisateurs", "doit_changer_mot_de_passe")
    op.drop_column("utilisateurs", "adresse")
    op.drop_column("utilisateurs", "nif_cin")
    op.drop_column("utilisateurs", "date_naissance")
    op.drop_column("utilisateurs", "prenom")
