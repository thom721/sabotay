"""super_admins table

Revision ID: 0008
Revises: 0007
Create Date: 2026-08-01

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0008"
down_revision: Union[str, None] = "0007"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "super_admins",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("nom", sa.String(), nullable=False),
        sa.Column("email", sa.String(), nullable=False),
        sa.Column("hashed_password", sa.String(), nullable=False),
        sa.Column(
            "date_creation",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column("derniere_connexion", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index(
        "ix_super_admins_email", "super_admins", ["email"], unique=True
    )


def downgrade() -> None:
    op.drop_index("ix_super_admins_email", table_name="super_admins")
    op.drop_table("super_admins")
