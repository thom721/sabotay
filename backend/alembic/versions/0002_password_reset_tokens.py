"""password reset tokens

Revision ID: 0002
Revises: 0001
Create Date: 2026-07-31

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0002"
down_revision: Union[str, None] = "0001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "password_reset_tokens",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "utilisateur_id",
            sa.Integer(),
            sa.ForeignKey("utilisateurs.id"),
            nullable=False,
        ),
        sa.Column("code_hash", sa.String(), nullable=False),
        sa.Column("canal", sa.Enum("SMS", "EMAIL", name="canalreset"), nullable=False),
        sa.Column("tentatives", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("utilise", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("date_creation", sa.DateTime(timezone=True), nullable=False),
        sa.Column("date_expiration", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index(
        "ix_password_reset_tokens_utilisateur_id",
        "password_reset_tokens",
        ["utilisateur_id"],
    )


def downgrade() -> None:
    op.drop_table("password_reset_tokens")
    sa.Enum(name="canalreset").drop(op.get_bind(), checkfirst=True)
