from datetime import timedelta
from decimal import Decimal

from sqlalchemy import func
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select

from app.models.compte_sabotay import CompteSabotay
from app.schemas.compte_sabotay import CompteSabotayCreate

_MAX_TENTATIVES_NUMERO = 5


async def _prochain_rang(session: AsyncSession, *, entreprise_id: str) -> int:
    # MAX(rang) plutôt que COUNT(*) : un compte supprimé ne fait pas régresser
    # le rang, ce qui éviterait de régénérer un numéro déjà attribué.
    result = await session.execute(
        select(func.max(CompteSabotay.numero_compte)).where(
            CompteSabotay.entreprise_id == entreprise_id
        )
    )
    dernier_numero = result.scalar_one_or_none()
    if dernier_numero is None:
        return 1
    return int(dernier_numero.removeprefix("SB-")) + 1


async def create(
    session: AsyncSession, *, entreprise_id: str, data: CompteSabotayCreate
) -> CompteSabotay:
    date_fin_prevue = data.date_debut + timedelta(days=data.duree_jours)
    montant_total_attendu = data.montant_journalier * Decimal(data.duree_jours)

    rang = await _prochain_rang(session, entreprise_id=entreprise_id)
    for tentative in range(_MAX_TENTATIVES_NUMERO):
        compte = CompteSabotay(
            entreprise_id=entreprise_id,
            client_id=data.client_id,
            numero_compte=f"SB-{rang:06d}",
            montant_journalier=data.montant_journalier,
            date_debut=data.date_debut,
            duree_jours=data.duree_jours,
            date_fin_prevue=date_fin_prevue,
            montant_total_attendu=montant_total_attendu,
        )
        session.add(compte)
        try:
            await session.commit()
        except IntegrityError:
            # Numéro pris entre-temps par une création concurrente : on
            # retente avec le rang suivant plutôt que de laisser échouer
            # la requête (cause directe d'erreurs de saisie côté agent).
            await session.rollback()
            if tentative == _MAX_TENTATIVES_NUMERO - 1:
                raise
            rang += 1
            continue
        await session.refresh(compte)
        return compte

    raise AssertionError("unreachable")


async def get_for_tenant(
    session: AsyncSession, *, compte_id: str, entreprise_id: str
) -> CompteSabotay | None:
    statement = select(CompteSabotay).where(
        CompteSabotay.id == compte_id, CompteSabotay.entreprise_id == entreprise_id
    )
    result = await session.execute(statement)
    return result.scalar_one_or_none()


async def get_by_numero(
    session: AsyncSession, *, numero_compte: str, entreprise_id: str
) -> CompteSabotay | None:
    statement = select(CompteSabotay).where(
        CompteSabotay.numero_compte == numero_compte,
        CompteSabotay.entreprise_id == entreprise_id,
    )
    result = await session.execute(statement)
    return result.scalar_one_or_none()


async def list_for_client(
    session: AsyncSession, *, client_id: str, entreprise_id: str
) -> list[CompteSabotay]:
    statement = select(CompteSabotay).where(
        CompteSabotay.client_id == client_id,
        CompteSabotay.entreprise_id == entreprise_id,
    )
    result = await session.execute(statement)
    return list(result.scalars().all())


async def get_for_client(
    session: AsyncSession, *, compte_id: str, client_id: str, entreprise_id: str
) -> CompteSabotay | None:
    """Vérifie qu'un compte appartient bien au client authentifié avant de
    lui exposer son solde/historique (portail libre-service, PRD §8.8)."""
    statement = select(CompteSabotay).where(
        CompteSabotay.id == compte_id,
        CompteSabotay.client_id == client_id,
        CompteSabotay.entreprise_id == entreprise_id,
    )
    result = await session.execute(statement)
    return result.scalar_one_or_none()
