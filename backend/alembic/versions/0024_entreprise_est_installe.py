"""entreprises : suivi de l'installation bureau (est_installe)

Revision ID: 0024
Revises: 0023
Create Date: 2026-08-13

Ajoute entreprises.est_installe — vrai dès la première synchronisation
réussie d'un poste bureau (voir sync.py::_touch_sync_state), jamais réglé
manuellement à True. Un super-admin peut le repasser à False pour permettre
une réinstallation (voir superadmin.py).
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0024"
down_revision: Union[str, None] = "0023"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "entreprises",
        sa.Column("est_installe", sa.Boolean(), nullable=False, server_default=sa.false()),
    )


def downgrade() -> None:
    op.drop_column("entreprises", "est_installe")
