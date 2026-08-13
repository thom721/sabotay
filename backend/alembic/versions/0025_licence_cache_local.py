"""licence_cache_local : cache Ed25519 vérifié pour l'abonnement hors-ligne

Revision ID: 0025
Revises: 0024
Create Date: 2026-08-13

N'a de sens que sur un poste bureau local (LOCAL_MODE=true) — sur le cloud
cette table reste toujours vide (le cloud n'a pas besoin de vérifier sa
propre signature). Créée quand même côté cloud pour rester dans un schéma
Alembic unique — voir aussi platform_config/sync_state, même situation.
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0025"
down_revision: Union[str, None] = "0024"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "licence_cache_local",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("payload_json", sa.String(), nullable=False),
        sa.Column("fetched_at", sa.DateTime(timezone=False), nullable=False),
    )


def downgrade() -> None:
    op.drop_table("licence_cache_local")
