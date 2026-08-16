import logging
from typing import AsyncGenerator

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.core.config import settings

logger = logging.getLogger("sabotaypro.db")

if settings.LOCAL_MODE:
    # Mode local (Phase 2a) : SQLite mono-tenant, jamais migré via Alembic —
    # voir le hook create_all() + sync_schema_local() dans main.py. Le
    # SQLite local n'est qu'un cache/staging synchronisé avec le cloud, pas
    # une source de vérité versionnée, donc pas de dialecte Postgres-
    # spécifique attendu ici.
    engine = create_async_engine(
        f"sqlite+aiosqlite:///{settings.LOCAL_DATABASE_PATH}", echo=False, future=True
    )
else:
    if not settings.DATABASE_URL:
        raise RuntimeError("DATABASE_URL est requis quand LOCAL_MODE=False")
    engine = create_async_engine(settings.DATABASE_URL, echo=False, future=True)

async_session_maker = async_sessionmaker(
    engine, class_=AsyncSession, expire_on_commit=False
)


async def get_session() -> AsyncGenerator[AsyncSession, None]:
    async with async_session_maker() as session:
        yield session


def sync_schema_local(sync_conn) -> None:
    """Filet de sécurité pour le SQLite local — appelé depuis `main.py` juste
    après `create_all()` (qui ne crée que les tables manquantes, jamais les
    colonnes manquantes sur une table déjà existante). Un poste bureau déjà
    installé avant l'ajout d'un champ à un modèle (ex. Epic 18
    `transactions.numero`, Epic 19 `entreprises.logo_data`) ne recevrait
    donc jamais cette colonne sans ce garde-fou.

    Même principe que `_sync_schema_from_models()` de pos_api
    (`api/main.py`), qui remplace Alembic pour la même raison dans un
    exécutable compilé : Alembic a besoin de ses fichiers de migration
    accessibles sur disque à l'exécution, absents d'un binaire figé
    (PyInstaller côté pos_api, Nuitka côté SabotayPro — voir Epic 5).

    Simplification délibérée par rapport à pos_api : les colonnes sont
    toujours ajoutées NULLABLE, même si le modèle Python les déclare NOT
    NULL — un `ALTER TABLE ADD COLUMN NOT NULL` sans valeur par défaut
    échoue dès que la table contient des lignes. Sans conséquence en
    pratique : l'application fournit toujours une valeur à la création
    (`default_factory`) pour toute nouvelle ligne ; seules les lignes déjà
    existantes avant la mise à jour du poste bureau resteraient avec cette
    colonne à NULL, ce qui est cosmétique (ex. un vieux reçu réimprimé sans
    numéro lisible) plutôt que bloquant."""
    from sqlalchemy import inspect
    from sqlmodel import SQLModel

    inspecteur = inspect(sync_conn)
    tables_existantes = set(inspecteur.get_table_names())

    for table in SQLModel.metadata.sorted_tables:
        if table.name not in tables_existantes:
            continue
        colonnes_existantes = {col["name"] for col in inspecteur.get_columns(table.name)}
        for colonne in table.columns:
            if colonne.name in colonnes_existantes:
                continue
            type_sql = colonne.type.compile(dialect=sync_conn.dialect)
            sync_conn.exec_driver_sql(
                f'ALTER TABLE "{table.name}" ADD COLUMN "{colonne.name}" {type_sql}'
            )
            logger.info("Colonne locale ajoutée : %s.%s", table.name, colonne.name)
