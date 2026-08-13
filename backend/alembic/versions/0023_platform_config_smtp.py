"""platform_config : configuration SMTP dynamique (super-admin → Paramètres → Email)

Revision ID: 0023
Revises: 0022
Create Date: 2026-08-13

Ajoute les colonnes smtp_* à platform_config — source de vérité pour
core/notifications.py::send_email(), qui garde les valeurs statiques .env
(settings.SMTP_*) en repli tant qu'elles sont vides ici. Même principe que
PlatformConfig.smtp_* de pos_api.
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0023"
down_revision: Union[str, None] = "0022"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("platform_config", sa.Column("smtp_host", sa.String(), nullable=True))
    op.add_column(
        "platform_config",
        sa.Column("smtp_port", sa.Integer(), nullable=False, server_default="587"),
    )
    op.add_column("platform_config", sa.Column("smtp_user", sa.String(), nullable=True))
    op.add_column("platform_config", sa.Column("smtp_password", sa.String(), nullable=True))
    op.add_column("platform_config", sa.Column("smtp_from_email", sa.String(), nullable=True))


def downgrade() -> None:
    op.drop_column("platform_config", "smtp_from_email")
    op.drop_column("platform_config", "smtp_password")
    op.drop_column("platform_config", "smtp_user")
    op.drop_column("platform_config", "smtp_port")
    op.drop_column("platform_config", "smtp_host")
