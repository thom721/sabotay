"""initial schema

Revision ID: 0001
Revises:
Create Date: 2026-07-30

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "entreprises",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("nom", sa.String(), nullable=False),
        sa.Column("devise", sa.String(), nullable=False, server_default="HTG"),
        sa.Column(
            "fuseau_horaire",
            sa.String(),
            nullable=False,
            server_default="America/Port-au-Prince",
        ),
        sa.Column(
            "statut",
            sa.Enum("ESSAI", "ACTIF", "SUSPENDU", name="statutentreprise"),
            nullable=False,
            server_default="ESSAI",
        ),
        sa.Column("date_creation", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_entreprises_nom", "entreprises", ["nom"])

    op.create_table(
        "utilisateurs",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "entreprise_id",
            sa.Integer(),
            sa.ForeignKey("entreprises.id"),
            nullable=False,
        ),
        sa.Column("nom", sa.String(), nullable=False),
        sa.Column("telephone", sa.String(), nullable=False),
        sa.Column("email", sa.String(), nullable=True),
        sa.Column("hashed_password", sa.String(), nullable=False),
        sa.Column(
            "role",
            sa.Enum("ADMIN", "MANAGER", "AGENT", name="roleutilisateur"),
            nullable=False,
        ),
        sa.Column(
            "statut",
            sa.Enum("ACTIF", "INACTIF", name="statututilisateur"),
            nullable=False,
            server_default="ACTIF",
        ),
        sa.Column("date_creation", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_utilisateurs_entreprise_id", "utilisateurs", ["entreprise_id"])
    op.create_index("ix_utilisateurs_telephone", "utilisateurs", ["telephone"])
    op.create_index("ix_utilisateurs_email", "utilisateurs", ["email"])

    op.create_table(
        "clients",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "entreprise_id",
            sa.Integer(),
            sa.ForeignKey("entreprises.id"),
            nullable=False,
        ),
        sa.Column("nom", sa.String(), nullable=False),
        sa.Column("telephone", sa.String(), nullable=False),
        sa.Column("adresse", sa.String(), nullable=True),
        sa.Column("photo_url", sa.String(), nullable=True),
        sa.Column(
            "agent_assigne_id",
            sa.Integer(),
            sa.ForeignKey("utilisateurs.id"),
            nullable=True,
        ),
        sa.Column("code_acces", sa.String(), nullable=True),
        sa.Column(
            "statut",
            sa.Enum("ACTIF", "INACTIF", name="statutclient"),
            nullable=False,
            server_default="ACTIF",
        ),
        sa.Column("date_creation", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_clients_entreprise_id", "clients", ["entreprise_id"])
    op.create_index("ix_clients_telephone", "clients", ["telephone"])

    op.create_table(
        "comptes_sabotay",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "entreprise_id",
            sa.Integer(),
            sa.ForeignKey("entreprises.id"),
            nullable=False,
        ),
        sa.Column("client_id", sa.Integer(), sa.ForeignKey("clients.id"), nullable=False),
        sa.Column("montant_journalier", sa.Numeric(12, 2), nullable=False),
        sa.Column("date_debut", sa.Date(), nullable=False),
        sa.Column("duree_jours", sa.Integer(), nullable=False),
        sa.Column("date_fin_prevue", sa.Date(), nullable=False),
        sa.Column("montant_total_attendu", sa.Numeric(14, 2), nullable=False),
        sa.Column(
            "statut",
            sa.Enum("ACTIF", "EN_RETARD", "COMPLETE", "ANNULE", name="statutcompte"),
            nullable=False,
            server_default="ACTIF",
        ),
        sa.Column("date_creation", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_comptes_sabotay_entreprise_id", "comptes_sabotay", ["entreprise_id"])
    op.create_index("ix_comptes_sabotay_client_id", "comptes_sabotay", ["client_id"])

    op.create_table(
        "transactions",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "entreprise_id",
            sa.Integer(),
            sa.ForeignKey("entreprises.id"),
            nullable=False,
        ),
        sa.Column(
            "compte_id",
            sa.Integer(),
            sa.ForeignKey("comptes_sabotay.id"),
            nullable=False,
        ),
        sa.Column("date", sa.Date(), nullable=False),
        sa.Column("montant", sa.Numeric(12, 2), nullable=False),
        sa.Column(
            "statut",
            sa.Enum("PAYE", "MANQUE", name="statuttransaction"),
            nullable=False,
        ),
        sa.Column(
            "collecte_par_id",
            sa.Integer(),
            sa.ForeignKey("utilisateurs.id"),
            nullable=False,
        ),
        sa.Column("cree_le", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_transactions_entreprise_id", "transactions", ["entreprise_id"])
    op.create_index("ix_transactions_compte_id", "transactions", ["compte_id"])

    op.create_table(
        "abonnements",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "entreprise_id",
            sa.Integer(),
            sa.ForeignKey("entreprises.id"),
            nullable=False,
            unique=True,
        ),
        sa.Column(
            "plan",
            sa.Enum("STARTER", "PRO", "BUSINESS", name="planabonnement"),
            nullable=False,
            server_default="STARTER",
        ),
        sa.Column("date_debut", sa.Date(), nullable=False),
        sa.Column("date_renouvellement", sa.Date(), nullable=True),
        sa.Column(
            "statut",
            sa.Enum("ESSAI", "ACTIF", "SUSPENDU", "ANNULE", name="statutabonnement"),
            nullable=False,
            server_default="ESSAI",
        ),
        sa.Column("date_creation", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_abonnements_entreprise_id", "abonnements", ["entreprise_id"])


def downgrade() -> None:
    op.drop_table("abonnements")
    op.drop_table("transactions")
    op.drop_table("comptes_sabotay")
    op.drop_table("clients")
    op.drop_table("utilisateurs")
    op.drop_table("entreprises")

    for enum_name in (
        "statutentreprise",
        "roleutilisateur",
        "statututilisateur",
        "statutclient",
        "statutcompte",
        "statuttransaction",
        "planabonnement",
        "statutabonnement",
    ):
        sa.Enum(name=enum_name).drop(op.get_bind(), checkfirst=True)
