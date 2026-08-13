"""sync: colonnes updated_at (watermarks) + table sync_state

Revision ID: 0017
Revises: 0016
Create Date: 2026-08-12

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0017"
down_revision: Union[str, None] = "0016"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

_TABLES = ["entreprises", "utilisateurs", "clients", "comptes_sabotay", "transactions"]


def upgrade() -> None:
    for table in _TABLES:
        op.add_column(
            table,
            sa.Column(
                "updated_at",
                sa.DateTime(timezone=True),
                nullable=False,
                server_default=sa.func.now(),
            ),
        )

    op.create_table(
        "sync_state",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("device_id", sa.String(), nullable=False),
        sa.Column("entreprise_id", sa.Integer(), sa.ForeignKey("entreprises.id"), nullable=False),
        sa.Column("entity_name", sa.String(), nullable=False),
        sa.Column("last_push_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_pull_at", sa.DateTime(timezone=True), nullable=True),
        sa.UniqueConstraint("device_id", "entity_name", name="uq_sync_state_device_entity"),
    )
    op.create_index("ix_sync_state_device_id", "sync_state", ["device_id"])
    op.create_index("ix_sync_state_entreprise_id", "sync_state", ["entreprise_id"])


def downgrade() -> None:
    op.drop_table("sync_state")
    for table in _TABLES:
        op.drop_column(table, "updated_at")
