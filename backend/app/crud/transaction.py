from datetime import date
from decimal import Decimal

from sqlalchemy import func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select

from app.models.compte_sabotay import CompteSabotay, StatutCompte
from app.models.transaction import Transaction, TypeTransaction
from app.schemas.compte_sabotay import CompteSabotaySolde
from app.schemas.transaction import RetraitCreate, TransactionCreate


async def create(
    session: AsyncSession,
    *,
    entreprise_id: int,
    collecte_par_id: int,
    collecte_par_nom: str,
    data: TransactionCreate,
    compte: CompteSabotay,
) -> Transaction:
    """Enregistre une collecte et met à jour le statut du compte (PRD §7.3,
    §8.5, §8.6). Le montant n'est jamais fourni par le client — il est
    toujours nb_jours * montant_journalier, pour qu'il ne soit pas
    modifiable même en contournant l'UI."""
    montant = compte.montant_journalier * data.nb_jours
    transaction = Transaction(
        entreprise_id=entreprise_id,
        compte_id=data.compte_id,
        date=data.date,
        montant=montant,
        type=TypeTransaction.COLLECTE,
        nb_jours=data.nb_jours,
        collecte_par_id=collecte_par_id,
        collecte_par_nom=collecte_par_nom,
    )
    session.add(transaction)
    await session.flush()

    if compte.statut not in (StatutCompte.COMPLETE, StatutCompte.ANNULE):
        solde = await get_solde(session, compte=compte)
        if solde.montant_collecte >= compte.montant_total_attendu:
            compte.statut = StatutCompte.COMPLETE
        elif solde.jours_manques > 0:
            compte.statut = StatutCompte.EN_RETARD
        else:
            compte.statut = StatutCompte.ACTIF
        session.add(compte)

    await session.commit()
    await session.refresh(transaction)
    return transaction


async def create_retrait(
    session: AsyncSession,
    *,
    entreprise_id: int,
    collecte_par_id: int,
    collecte_par_nom: str,
    data: RetraitCreate,
    compte: CompteSabotay,
    frais_retrait: Decimal,
) -> Transaction:
    """Enregistre un retrait partiel — possible à tout moment, plafonné au
    solde disponible. Les frais sont copiés depuis la config entreprise, pas
    modifiables par l'agent (§ demande produit : tout se configure sur le
    web)."""
    solde = await get_solde(session, compte=compte)
    if data.montant > solde.solde_disponible:
        raise ValueError("Montant de retrait supérieur au solde disponible")

    transaction = Transaction(
        entreprise_id=entreprise_id,
        compte_id=data.compte_id,
        date=data.date,
        montant=data.montant,
        type=TypeTransaction.RETRAIT,
        frais=frais_retrait,
        collecte_par_id=collecte_par_id,
        collecte_par_nom=collecte_par_nom,
    )
    session.add(transaction)

    # Un retrait qui vide le solde disponible clôt le compte — il reste
    # visible avec tout son historique, seul le statut change.
    if solde.solde_disponible - data.montant <= 0:
        compte.statut = StatutCompte.INACTIF
        session.add(compte)

    await session.commit()
    await session.refresh(transaction)
    return transaction


async def get_solde(session: AsyncSession, *, compte: CompteSabotay) -> CompteSabotaySolde:
    """Solde d'un compte — les jours manqués ne sont plus des lignes
    stockées : ils se déduisent des jours écoulés depuis date_debut face au
    nombre de jours réellement couverts par des collectes (nb_jours), donc
    toujours à jour sans job planifié ni action manuelle de l'agent."""
    statement = select(
        func.coalesce(
            func.sum(Transaction.montant).filter(
                Transaction.type == TypeTransaction.COLLECTE
            ),
            0,
        ),
        func.coalesce(
            func.sum(Transaction.montant).filter(
                Transaction.type == TypeTransaction.RETRAIT
            ),
            0,
        ),
        func.coalesce(
            func.sum(Transaction.nb_jours).filter(
                Transaction.type == TypeTransaction.COLLECTE
            ),
            0,
        ),
    ).where(Transaction.compte_id == compte.id)

    result = await session.execute(statement)
    montant_collecte, montant_retire, jours_payes = result.one()
    montant_collecte = Decimal(montant_collecte)
    montant_retire = Decimal(montant_retire)
    jours_payes = int(jours_payes)

    jours_dus = max(0, min((date.today() - compte.date_debut).days + 1, compte.duree_jours))
    jours_manques = max(0, jours_dus - jours_payes)
    dette = Decimal(jours_manques) * compte.montant_journalier

    return CompteSabotaySolde(
        compte_id=compte.id,
        montant_total_attendu=compte.montant_total_attendu,
        montant_collecte=montant_collecte,
        montant_retire=montant_retire,
        solde_restant=compte.montant_total_attendu - montant_collecte,
        solde_disponible=montant_collecte - montant_retire,
        dette=dette,
        jours_manques=jours_manques,
    )


async def list_for_compte(session: AsyncSession, *, compte_id: int) -> list[Transaction]:
    statement = (
        select(Transaction)
        .where(Transaction.compte_id == compte_id)
        .order_by(Transaction.date.desc())
    )
    result = await session.execute(statement)
    return list(result.scalars().all())


async def get_statistiques_mois(
    session: AsyncSession, *, entreprise_id: int, debut_mois: date
) -> tuple[Decimal, int]:
    statement = select(
        func.coalesce(func.sum(Transaction.montant), 0),
        func.count(Transaction.id),
    ).where(
        Transaction.entreprise_id == entreprise_id,
        Transaction.type == TypeTransaction.COLLECTE,
        Transaction.date >= debut_mois,
    )
    result = await session.execute(statement)
    montant, nb_transactions = result.one()
    return Decimal(montant), nb_transactions


async def get_velocite_journaliere(
    session: AsyncSession, *, entreprise_id: int, date_debut: date, date_fin: date
) -> list[tuple[date, Decimal]]:
    statement = (
        select(Transaction.date, func.coalesce(func.sum(Transaction.montant), 0))
        .where(
            Transaction.entreprise_id == entreprise_id,
            Transaction.type == TypeTransaction.COLLECTE,
            Transaction.date >= date_debut,
            Transaction.date <= date_fin,
        )
        .group_by(Transaction.date)
        .order_by(Transaction.date)
    )
    result = await session.execute(statement)
    return [(jour, Decimal(montant)) for jour, montant in result.all()]


async def list_recent_for_tenant(
    session: AsyncSession, *, entreprise_id: int, limit: int = 10
) -> list[Transaction]:
    statement = (
        select(Transaction)
        .where(Transaction.entreprise_id == entreprise_id)
        .order_by(Transaction.cree_le.desc())
        .limit(limit)
    )
    result = await session.execute(statement)
    return list(result.scalars().all())


async def list_for_periode(
    session: AsyncSession,
    *,
    entreprise_id: int,
    date_debut: date,
    date_fin: date,
    collecte_par_id: int | None = None,
) -> list[Transaction]:
    """Transactions d'une période pour le rapport de collecte (§8.7 PRD) —
    filtré sur un agent précis quand fourni (un Agent ne voit que les
    siennes), sinon tout le tenant (Admin/Manager)."""
    conditions = [
        Transaction.entreprise_id == entreprise_id,
        Transaction.date >= date_debut,
        Transaction.date <= date_fin,
    ]
    if collecte_par_id is not None:
        conditions.append(Transaction.collecte_par_id == collecte_par_id)

    statement = select(Transaction).where(*conditions).order_by(Transaction.date.desc())
    result = await session.execute(statement)
    return list(result.scalars().all())
