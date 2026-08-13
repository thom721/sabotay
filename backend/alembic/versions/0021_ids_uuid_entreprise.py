"""ids: migration vers UUID (entreprises + toutes les entreprise_id restantes)

Revision ID: 0021
Revises: 0020
Create Date: 2026-08-12

Suite de 0019 (qui migrait utilisateurs/clients/comptes_sabotay/transactions).
Cette fois : `entreprises.id` lui-même, et toutes les colonnes qui restaient
en `int` malgré la décision initiale de les garder ainsi (justifiée par
"aucune n'est créée hors-ligne") — decision annulée : uniformiser tous les id
en UUID pour éliminer toute distinction à retenir plus tard.

Tables dont le id propre passe en UUID : entreprises, abonnements,
paiements_abonnement, password_reset_tokens, super_admins, platform_config,
sync_state.

Colonnes entreprise_id (FK vers entreprises.id) retypées en UUID : celles
migrées en 0019 (utilisateurs, clients, comptes_sabotay, transactions) plus
abonnements, paiements_abonnement, sync_state.

Colonne abonnement_id (FK vers abonnements.id) retypée en UUID :
paiements_abonnement.

Même approche par colonnes shadow que 0019 : ajout de colonnes UUID
nullables, backfill parents (entreprises, abonnements) avant enfants, bascule
des clés étrangères par jointure sur l'ancien id, puis swap des colonnes.
"""
import uuid
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy import inspect

# revision identifiers, used by Alembic.
revision: str = "0021"
down_revision: Union[str, None] = "0020"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


_ID_TABLES = [
    "entreprises",
    "abonnements",
    "paiements_abonnement",
    "password_reset_tokens",
    "super_admins",
    "platform_config",
    "sync_state",
]

_ENTREPRISE_ID_TABLES = [
    "utilisateurs",
    "clients",
    "comptes_sabotay",
    "transactions",
    "abonnements",
    "paiements_abonnement",
    "sync_state",
]


def _fk_name(inspector, table: str, column: str) -> str:
    for fk in inspector.get_foreign_keys(table):
        if column in fk["constrained_columns"]:
            return fk["name"]
    raise RuntimeError(f"Contrainte FK introuvable pour {table}.{column}")


def _unique_name(inspector, table: str, column: str) -> str:
    for uq in inspector.get_unique_constraints(table):
        if uq["column_names"] == [column]:
            return uq["name"]
    raise RuntimeError(f"Contrainte UNIQUE introuvable pour {table}.{column}")


def upgrade() -> None:
    conn = op.get_bind()

    # 1. Colonnes shadow UUID (nullables pour l'instant)
    for table in _ID_TABLES:
        op.add_column(table, sa.Column("new_id", sa.String(36), nullable=True))
    for table in set(_ENTREPRISE_ID_TABLES):
        op.add_column(table, sa.Column("new_entreprise_id", sa.String(36), nullable=True))
    op.add_column(
        "paiements_abonnement", sa.Column("new_abonnement_id", sa.String(36), nullable=True)
    )

    # 2. Backfill new_id — indépendant table par table (id propre, pas de FK)
    for table in _ID_TABLES:
        ids = [row[0] for row in conn.execute(sa.text(f"SELECT id FROM {table}"))]
        for old_id in ids:
            conn.execute(
                sa.text(f"UPDATE {table} SET new_id = :u WHERE id = :old"),
                {"u": str(uuid.uuid4()), "old": old_id},
            )

    # 3. Backfill des colonnes FK shadow par jointure ancien id -> new_id du parent
    for table in _ENTREPRISE_ID_TABLES:
        conn.execute(
            sa.text(
                f"UPDATE {table} t SET new_entreprise_id = e.new_id "
                f"FROM entreprises e WHERE t.entreprise_id = e.id"
            )
        )
    conn.execute(
        sa.text(
            "UPDATE paiements_abonnement p SET new_abonnement_id = a.new_id "
            "FROM abonnements a WHERE p.abonnement_id = a.id"
        )
    )

    # 4. Bascule : drop anciennes FK/UNIQUE (enfants d'abord) et PK, drop
    # colonnes int, renommer les colonnes shadow à leur place, ré-ajouter
    # PK/FK/UNIQUE.
    inspector = inspect(conn)

    op.drop_constraint(
        _fk_name(inspector, "paiements_abonnement", "abonnement_id"),
        "paiements_abonnement",
        type_="foreignkey",
    )
    for table in _ENTREPRISE_ID_TABLES:
        op.drop_constraint(
            _fk_name(inspector, table, "entreprise_id"), table, type_="foreignkey"
        )
    op.drop_constraint(
        _unique_name(inspector, "abonnements", "entreprise_id"),
        "abonnements",
        type_="unique",
    )

    for table in _ID_TABLES:
        pk_name = inspector.get_pk_constraint(table)["name"]
        op.drop_constraint(pk_name, table, type_="primary")

    op.drop_column("paiements_abonnement", "abonnement_id")
    for table in set(_ENTREPRISE_ID_TABLES):
        op.drop_column(table, "entreprise_id")
    for table in _ID_TABLES:
        op.drop_column(table, "id")

    for table in _ID_TABLES:
        op.alter_column(table, "new_id", new_column_name="id")
    for table in set(_ENTREPRISE_ID_TABLES):
        op.alter_column(table, "new_entreprise_id", new_column_name="entreprise_id")
    op.alter_column(
        "paiements_abonnement", "new_abonnement_id", new_column_name="abonnement_id"
    )

    for table in _ID_TABLES:
        op.alter_column(table, "id", nullable=False)
    for table in set(_ENTREPRISE_ID_TABLES):
        op.alter_column(table, "entreprise_id", nullable=False)
    op.alter_column("paiements_abonnement", "abonnement_id", nullable=False)

    for table in _ID_TABLES:
        op.create_primary_key(f"{table}_pkey", table, ["id"])

    for table in _ENTREPRISE_ID_TABLES:
        op.create_foreign_key(
            f"{table}_entreprise_id_fkey", table, "entreprises", ["entreprise_id"], ["id"]
        )
    op.create_foreign_key(
        "paiements_abonnement_abonnement_id_fkey",
        "paiements_abonnement",
        "abonnements",
        ["abonnement_id"],
        ["id"],
    )
    op.create_unique_constraint(
        "abonnements_entreprise_id_key", "abonnements", ["entreprise_id"]
    )
    # Les index simples (non-uniques) sur entreprise_id/abonnement_id ne
    # survivent PAS au rename : ils étaient attachés à l'ancienne colonne
    # int, supprimée avec elle par le DROP COLUMN (comportement Postgres,
    # constaté ici après coup — voir aussi la même correction dans 0019).
    # Recréation explicite (celui d'abonnements.entreprise_id est redondant
    # avec l'index de la contrainte UNIQUE, mais recréé pour fidélité avec
    # le schéma d'origine).
    op.create_index("ix_utilisateurs_entreprise_id", "utilisateurs", ["entreprise_id"])
    op.create_index("ix_clients_entreprise_id", "clients", ["entreprise_id"])
    op.create_index("ix_comptes_sabotay_entreprise_id", "comptes_sabotay", ["entreprise_id"])
    op.create_index("ix_transactions_entreprise_id", "transactions", ["entreprise_id"])
    op.create_index("ix_abonnements_entreprise_id", "abonnements", ["entreprise_id"])
    op.create_index(
        "ix_paiements_abonnement_abonnement_id", "paiements_abonnement", ["abonnement_id"]
    )
    op.create_index(
        "ix_paiements_abonnement_entreprise_id", "paiements_abonnement", ["entreprise_id"]
    )
    op.create_index("ix_sync_state_entreprise_id", "sync_state", ["entreprise_id"])


def downgrade() -> None:
    # Downgrade délibérément non supporté — même raisonnement que 0019 :
    # redescendre d'UUID vers un id entier signifierait générer de nouveaux
    # id séquentiels arbitraires, incompatible avec les données déjà
    # synchronisées vers d'éventuelles installations locales. Restaurer
    # depuis une sauvegarde si un retour arrière est nécessaire.
    raise NotImplementedError(
        "Downgrade non supporté pour la migration UUID — restaurer depuis une sauvegarde."
    )
