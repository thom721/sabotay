"""dates : passage à l'heure locale Haïti naïve (comme pos_api)

Revision ID: 0020
Revises: 0019
Create Date: 2026-08-12

Toutes les colonnes DateTime métier passent à TIMESTAMP WITHOUT TIME ZONE,
valeurs en heure locale Haïti (America/Port-au-Prince) naïve — même
convention que pos_api (`now_local()`, voir core/dt_utils.py), appliquée à
la création ET à la modification de tous les champs concernés, pas
seulement `updated_at` (la migration 0018 n'avait converti que ce champ,
vers UTC naïf — corrigé ici vers Haïti local, cohérent avec le reste et
avec `Entreprise.fuseau_horaire`, déjà "America/Port-au-Prince" par
défaut).
"""
from typing import Sequence, Union

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0020"
down_revision: Union[str, None] = "0019"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# Colonnes actuellement TIMESTAMP WITH TIME ZONE — conversion type + valeur
# en une seule opération (instant absolu -> représentation naïve Haïti).
_TZ_COLUMNS = [
    ("entreprises", "date_creation"),
    ("utilisateurs", "date_creation"),
    ("utilisateurs", "derniere_connexion"),
    ("clients", "date_creation"),
    ("clients", "derniere_connexion"),
    ("comptes_sabotay", "date_creation"),
    ("transactions", "cree_le"),
    ("abonnements", "date_creation"),
    ("abonnements", "date_paiement"),
    ("paiements_abonnement", "date_paiement"),
    ("password_reset_tokens", "date_creation"),
    ("password_reset_tokens", "date_expiration"),
    ("super_admins", "date_creation"),
    ("super_admins", "derniere_connexion"),
    ("sync_state", "last_push_at"),
    ("sync_state", "last_pull_at"),
]

# Déjà TIMESTAMP WITHOUT TIME ZONE depuis la migration 0018, mais valeurs
# encore en UTC naïf (now_utc_naive, aujourd'hui renommé now_local et
# repointé sur l'heure Haïti) — seule la valeur doit être décalée, pas le
# type de colonne.
_NAIVE_UTC_COLUMNS = [
    ("entreprises", "updated_at"),
    ("utilisateurs", "updated_at"),
    ("clients", "updated_at"),
    ("comptes_sabotay", "updated_at"),
    ("transactions", "updated_at"),
]


def upgrade() -> None:
    for table, column in _TZ_COLUMNS:
        op.execute(
            f"ALTER TABLE {table} ALTER COLUMN {column} TYPE TIMESTAMP "
            f"USING {column} AT TIME ZONE 'America/Port-au-Prince'"
        )
    for table, column in _NAIVE_UTC_COLUMNS:
        op.execute(
            f"UPDATE {table} SET {column} = "
            f"({column} AT TIME ZONE 'UTC') AT TIME ZONE 'America/Port-au-Prince'"
        )


def downgrade() -> None:
    raise NotImplementedError(
        "Downgrade non supporté pour 0020 (conversion de fuseau horaire) — "
        "restaurer une sauvegarde d'avant-migration plutôt que de tenter un "
        "retour arrière."
    )
