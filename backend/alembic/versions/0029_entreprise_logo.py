"""entreprises : logo (data URI)

Revision ID: 0029
Revises: 0028
Create Date: 2026-08-17

Ajoute `logo_data` (data URI base64, ex. "data:image/png;base64,...") —
choisi plutôt qu'un fichier sur disque + URL car aucune infra de stockage de
fichiers n'existe (cloud ni poste bureau) et `entreprises` fait déjà partie
des entités synchronisées (sync.py::ENTITES) : un champ texte simple
traverse ce mécanisme générique sans rien y ajouter.
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0029"
down_revision: Union[str, None] = "0028"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("entreprises", sa.Column("logo_data", sa.String(), nullable=True))


def downgrade() -> None:
    op.drop_column("entreprises", "logo_data")
