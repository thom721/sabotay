"""codes_installation : lier un poste local au cloud sans email/mot de passe

Revision ID: 0022
Revises: 0021
Create Date: 2026-08-12

Table `codes_installation` — même pattern que `InstallationCode` de pos_api,
simplifié : pas de notion de dépôt/warehouse (un seul poste local par
entreprise, voir Epic 2 dans EPICS.md), donc pas d'étape de "claim" séparée.
Un code appartient directement à une entreprise et se marque `utilise=True`
dès son échange contre un jeton de sync (`POST /sync/redeem-code`).
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0022"
down_revision: Union[str, None] = "0021"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "codes_installation",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("code", sa.String(20), nullable=False, unique=True),
        sa.Column(
            "entreprise_id",
            sa.String(36),
            sa.ForeignKey("entreprises.id"),
            nullable=False,
        ),
        sa.Column("cree_le", sa.DateTime(timezone=False), nullable=False),
        sa.Column("utilise", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("utilise_le", sa.DateTime(timezone=False), nullable=True),
    )
    op.create_index("ix_codes_installation_code", "codes_installation", ["code"])
    op.create_index("ix_codes_installation_entreprise_id", "codes_installation", ["entreprise_id"])


def downgrade() -> None:
    op.drop_table("codes_installation")
