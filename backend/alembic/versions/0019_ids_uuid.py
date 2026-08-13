"""ids: migration vers UUID (utilisateurs, clients, comptes_sabotay, transactions)

Revision ID: 0019
Revises: 0018
Create Date: 2026-08-12

Les id de ces 4 tables (+ la FK password_reset_tokens.utilisateur_id) passent
d'entier auto-incrémenté à UUID généré en mémoire (voir app/models/*.py,
default_factory=lambda: str(uuid.uuid4())) — même choix que pos_api
(UUIDBase). Objectif : deux installations (cloud, poste local en Phase 2b)
ne peuvent jamais générer le même id, connectées ou non, ce qui élimine
tout le mécanisme d'id négatifs/remap ajouté en Phase 2a (voir
app/api/v1/endpoints/sync.py et app/services/local_sync_client.py,
simplifiés dans le même changement que cette migration).

Approche par colonnes "shadow" pour préserver les données et relations
existantes (pas de perte, contrairement à un simple drop/recreate) :
ajout de colonnes UUID nullables, backfill parents→enfants, bascule des
clés étrangères par jointure sur l'ancien id, puis swap des colonnes.

entreprises/abonnements/paiements_abonnement/super_admins/platform_config/
sync_state restent en `int` — aucune n'est créée hors-ligne.
"""
import uuid
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy import inspect

# revision identifiers, used by Alembic.
revision: str = "0019"
down_revision: Union[str, None] = "0018"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _fk_name(inspector, table: str, column: str) -> str:
    for fk in inspector.get_foreign_keys(table):
        if column in fk["constrained_columns"]:
            return fk["name"]
    raise RuntimeError(f"Contrainte FK introuvable pour {table}.{column}")


def upgrade() -> None:
    conn = op.get_bind()

    # 1. Colonnes shadow UUID (nullables pour l'instant)
    op.add_column("utilisateurs", sa.Column("new_id", sa.String(36), nullable=True))
    op.add_column("clients", sa.Column("new_id", sa.String(36), nullable=True))
    op.add_column("clients", sa.Column("new_agent_assigne_id", sa.String(36), nullable=True))
    op.add_column("comptes_sabotay", sa.Column("new_id", sa.String(36), nullable=True))
    op.add_column("comptes_sabotay", sa.Column("new_client_id", sa.String(36), nullable=True))
    op.add_column("transactions", sa.Column("new_id", sa.String(36), nullable=True))
    op.add_column("transactions", sa.Column("new_compte_id", sa.String(36), nullable=True))
    op.add_column("transactions", sa.Column("new_collecte_par_id", sa.String(36), nullable=True))
    op.add_column(
        "password_reset_tokens", sa.Column("new_utilisateur_id", sa.String(36), nullable=True)
    )

    # 2. Backfill new_id — parents avant enfants (utilisateurs/clients avant
    # comptes_sabotay/transactions, pour que les jointures de l'étape 3
    # trouvent toujours un new_id déjà rempli côté parent).
    for table in ("utilisateurs", "clients", "comptes_sabotay", "transactions"):
        ids = [row[0] for row in conn.execute(sa.text(f"SELECT id FROM {table}"))]
        for old_id in ids:
            conn.execute(
                sa.text(f"UPDATE {table} SET new_id = :u WHERE id = :old"),
                {"u": str(uuid.uuid4()), "old": old_id},
            )

    # 3. Backfill des colonnes FK shadow par jointure ancien id -> new_id du parent
    conn.execute(
        sa.text(
            "UPDATE clients c SET new_agent_assigne_id = u.new_id "
            "FROM utilisateurs u WHERE c.agent_assigne_id = u.id"
        )
    )
    conn.execute(
        sa.text(
            "UPDATE comptes_sabotay cs SET new_client_id = c.new_id "
            "FROM clients c WHERE cs.client_id = c.id"
        )
    )
    conn.execute(
        sa.text(
            "UPDATE transactions t SET new_compte_id = cs.new_id "
            "FROM comptes_sabotay cs WHERE t.compte_id = cs.id"
        )
    )
    conn.execute(
        sa.text(
            "UPDATE transactions t SET new_collecte_par_id = u.new_id "
            "FROM utilisateurs u WHERE t.collecte_par_id = u.id"
        )
    )
    conn.execute(
        sa.text(
            "UPDATE password_reset_tokens p SET new_utilisateur_id = u.new_id "
            "FROM utilisateurs u WHERE p.utilisateur_id = u.id"
        )
    )

    # 4. Bascule : drop anciennes FK (enfants d'abord) et PK, drop colonnes
    # int, renommer les colonnes shadow à leur place, ré-ajouter PK/FK.
    inspector = inspect(conn)

    op.drop_constraint(
        _fk_name(inspector, "transactions", "compte_id"), "transactions", type_="foreignkey"
    )
    op.drop_constraint(
        _fk_name(inspector, "transactions", "collecte_par_id"),
        "transactions",
        type_="foreignkey",
    )
    op.drop_constraint(
        _fk_name(inspector, "comptes_sabotay", "client_id"), "comptes_sabotay", type_="foreignkey"
    )
    op.drop_constraint(
        _fk_name(inspector, "clients", "agent_assigne_id"), "clients", type_="foreignkey"
    )
    op.drop_constraint(
        _fk_name(inspector, "password_reset_tokens", "utilisateur_id"),
        "password_reset_tokens",
        type_="foreignkey",
    )

    for table in ("utilisateurs", "clients", "comptes_sabotay", "transactions"):
        pk_name = inspector.get_pk_constraint(table)["name"]
        op.drop_constraint(pk_name, table, type_="primary")

    op.drop_column("transactions", "compte_id")
    op.drop_column("transactions", "collecte_par_id")
    op.drop_column("transactions", "id")
    op.alter_column("transactions", "new_id", new_column_name="id")
    op.alter_column("transactions", "new_compte_id", new_column_name="compte_id")
    op.alter_column("transactions", "new_collecte_par_id", new_column_name="collecte_par_id")

    op.drop_column("comptes_sabotay", "client_id")
    op.drop_column("comptes_sabotay", "id")
    op.alter_column("comptes_sabotay", "new_id", new_column_name="id")
    op.alter_column("comptes_sabotay", "new_client_id", new_column_name="client_id")

    op.drop_column("clients", "agent_assigne_id")
    op.drop_column("clients", "id")
    op.alter_column("clients", "new_id", new_column_name="id")
    op.alter_column("clients", "new_agent_assigne_id", new_column_name="agent_assigne_id")

    op.drop_column("utilisateurs", "id")
    op.alter_column("utilisateurs", "new_id", new_column_name="id")

    op.drop_column("password_reset_tokens", "utilisateur_id")
    op.alter_column("password_reset_tokens", "new_utilisateur_id", new_column_name="utilisateur_id")

    op.alter_column("utilisateurs", "id", nullable=False)
    op.alter_column("clients", "id", nullable=False)
    op.alter_column("comptes_sabotay", "id", nullable=False)
    op.alter_column("comptes_sabotay", "client_id", nullable=False)
    op.alter_column("transactions", "id", nullable=False)
    op.alter_column("transactions", "compte_id", nullable=False)
    op.alter_column("transactions", "collecte_par_id", nullable=False)
    op.alter_column("password_reset_tokens", "utilisateur_id", nullable=False)
    # agent_assigne_id reste nullable (FK optionnelle d'origine).

    op.create_primary_key("utilisateurs_pkey", "utilisateurs", ["id"])
    op.create_primary_key("clients_pkey", "clients", ["id"])
    op.create_primary_key("comptes_sabotay_pkey", "comptes_sabotay", ["id"])
    op.create_primary_key("transactions_pkey", "transactions", ["id"])

    op.create_foreign_key(
        "clients_agent_assigne_id_fkey", "clients", "utilisateurs", ["agent_assigne_id"], ["id"]
    )
    op.create_foreign_key(
        "comptes_sabotay_client_id_fkey", "comptes_sabotay", "clients", ["client_id"], ["id"]
    )
    op.create_foreign_key(
        "transactions_compte_id_fkey", "transactions", "comptes_sabotay", ["compte_id"], ["id"]
    )
    op.create_foreign_key(
        "transactions_collecte_par_id_fkey",
        "transactions",
        "utilisateurs",
        ["collecte_par_id"],
        ["id"],
    )
    op.create_foreign_key(
        "password_reset_tokens_utilisateur_id_fkey",
        "password_reset_tokens",
        "utilisateurs",
        ["utilisateur_id"],
        ["id"],
    )
    # Les index simples (non-uniques) sur ces colonnes ne survivent PAS au
    # rename : ils étaient attachés à l'ancienne colonne int, supprimée avec
    # elle par le DROP COLUMN (comportement Postgres). Recréation explicite.
    op.create_index("ix_comptes_sabotay_client_id", "comptes_sabotay", ["client_id"])
    op.create_index("ix_transactions_compte_id", "transactions", ["compte_id"])
    op.create_index(
        "ix_password_reset_tokens_utilisateur_id", "password_reset_tokens", ["utilisateur_id"]
    )


def downgrade() -> None:
    # Downgrade délibérément non supporté : redescendre d'UUID vers un id
    # entier signifierait générer de nouveaux id séquentiels arbitraires
    # (les entiers d'origine ne sont pas récupérables après l'upgrade), ce
    # qui casserait silencieusement toute référence externe déjà construite
    # sur les UUID (jetons de sync émis, éventuels exports). Restaurer une
    # sauvegarde d'avant-migration est le chemin de retour recommandé.
    raise NotImplementedError(
        "Downgrade non supporté pour 0019 (migration UUID) — restaurer une "
        "sauvegarde d'avant-migration plutôt que de tenter un retour arrière."
    )
