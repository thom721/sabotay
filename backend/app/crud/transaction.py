from datetime import date
from decimal import Decimal

from sqlalchemy import func, or_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select

from app.models.client import Client
from app.models.compte_sabotay import CompteSabotay, StatutCompte
from app.models.transaction import Transaction, TypeTransaction
from app.schemas.compte_sabotay import CompteSabotaySolde
from app.schemas.transaction import RetraitCreate, TransactionCreate


async def create(
    session: AsyncSession,
    *,
    entreprise_id: str,
    collecte_par_id: str,
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
    entreprise_id: str,
    collecte_par_id: str,
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


def calculer_champs_solde(
    compte: CompteSabotay,
    montant_collecte: Decimal,
    montant_retire: Decimal,
    jours_payes: int,
) -> dict:
    """Dérive solde/dette/jours manqués à partir des sommes déjà agrégées —
    factorisé pour être partagé entre `get_solde` (un compte) et
    `get_soldes_bulk` (plusieurs comptes d'un coup, cache offline mobile
    Epic 6), sans dupliquer la formule."""
    jours_dus = max(0, min((date.today() - compte.date_debut).days + 1, compte.duree_jours))
    jours_manques = max(0, jours_dus - jours_payes)
    dette = Decimal(jours_manques) * compte.montant_journalier
    return {
        "montant_collecte": montant_collecte,
        "montant_retire": montant_retire,
        "solde_restant": compte.montant_total_attendu - montant_collecte,
        "solde_disponible": montant_collecte - montant_retire,
        "dette": dette,
        "jours_manques": jours_manques,
    }


async def get_solde(session: AsyncSession, *, compte: CompteSabotay) -> CompteSabotaySolde:
    """Solde d'un compte — les jours manqués ne sont plus des lignes
    stockées : ils se déduisent des jours écoulés depuis date_debut face au
    nombre de jours réellement couverts par des collectes (nb_jours), donc
    toujours à jour sans job planifié ni action manuelle de l'agent."""
    montant_collecte, montant_retire, jours_payes = (await get_soldes_bulk(
        session, compte_ids=[compte.id]
    )).get(compte.id, (Decimal("0"), Decimal("0"), 0))

    return CompteSabotaySolde(
        compte_id=compte.id,
        montant_total_attendu=compte.montant_total_attendu,
        **calculer_champs_solde(compte, montant_collecte, montant_retire, jours_payes),
    )


async def get_soldes_bulk(
    session: AsyncSession, *, compte_ids: list[str]
) -> dict[str, tuple[Decimal, Decimal, int]]:
    """Sommes agrégées (montant collecté, montant retiré, jours payés) pour
    plusieurs comptes en une seule requête groupée — évite un aller-retour
    par compte (`get_solde` l'utilise même pour un seul compte, pour ne pas
    dupliquer la requête). Comptes sans transaction absents du résultat,
    l'appelant traite ça comme (0, 0, 0)."""
    if not compte_ids:
        return {}

    statement = (
        select(
            Transaction.compte_id,
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
        )
        .where(Transaction.compte_id.in_(compte_ids))
        .group_by(Transaction.compte_id)
    )
    result = await session.execute(statement)
    return {
        compte_id: (Decimal(montant_collecte), Decimal(montant_retire), int(jours_payes))
        for compte_id, montant_collecte, montant_retire, jours_payes in result.all()
    }


async def list_for_compte(session: AsyncSession, *, compte_id: str) -> list[Transaction]:
    statement = (
        select(Transaction)
        .where(Transaction.compte_id == compte_id)
        .order_by(Transaction.date.desc())
    )
    result = await session.execute(statement)
    return list(result.scalars().all())


async def get_statistiques_mois(
    session: AsyncSession, *, entreprise_id: str, debut_mois: date
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
    session: AsyncSession, *, entreprise_id: str, date_debut: date, date_fin: date
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
    session: AsyncSession, *, entreprise_id: str, limit: int = 10
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
    entreprise_id: str,
    date_debut: date,
    date_fin: date,
    collecte_par_id: str | None = None,
) -> list[tuple[Transaction, str, str, str]]:
    """Transactions d'une période pour le rapport de collecte (§8.7 PRD) —
    filtré sur un agent précis quand fourni (un Agent ne voit que les
    siennes), sinon tout le tenant (Admin/Manager). Même jointure
    Client/CompteSabotay que `list_registre` (prénom, nom, numéro de compte)
    pour que chaque ligne du rapport soit imprimable individuellement (reçu)
    sans round-trip supplémentaire côté client."""
    conditions = [
        Transaction.entreprise_id == entreprise_id,
        Transaction.date >= date_debut,
        Transaction.date <= date_fin,
    ]
    if collecte_par_id is not None:
        conditions.append(Transaction.collecte_par_id == collecte_par_id)

    statement = (
        select(Transaction, Client.prenom, Client.nom, CompteSabotay.numero_compte)
        .join(CompteSabotay, CompteSabotay.id == Transaction.compte_id)
        .join(Client, Client.id == CompteSabotay.client_id)
        .where(*conditions)
        .order_by(Transaction.date.desc())
    )
    result = await session.execute(statement)
    return list(result.all())


async def list_registre(
    session: AsyncSession,
    *,
    entreprise_id: str,
    q: str | None = None,
    collecte_par_id: str | None = None,
    skip: int = 0,
    limit: int = 50,
) -> tuple[list[tuple[Transaction, str, str, str]], int]:
    """Registre paginé de toutes les transactions du tenant, avec recherche
    libre sur le client (nom/prénom), le numéro de compte ou l'agent — pour
    retrouver UNE transaction précise, contrairement à `list_for_periode` qui
    sert un rapport de synthèse borné à une période. Retourne des tuples
    (transaction, prénom, nom, numéro de compte) : la jointure est résolue
    ici plutôt que de faire porter ça à l'appelant (`compte_id` seul ne
    permettant aucune recherche par client côté UI)."""
    base = (
        select(Transaction, Client.prenom, Client.nom, CompteSabotay.numero_compte)
        .join(CompteSabotay, CompteSabotay.id == Transaction.compte_id)
        .join(Client, Client.id == CompteSabotay.client_id)
        .where(Transaction.entreprise_id == entreprise_id)
    )
    if collecte_par_id is not None:
        base = base.where(Transaction.collecte_par_id == collecte_par_id)
    if q:
        like = f"%{q}%"
        base = base.where(
            or_(
                Client.nom.ilike(like),
                Client.prenom.ilike(like),
                CompteSabotay.numero_compte.ilike(like),
                Transaction.collecte_par_nom.ilike(like),
            )
        )

    total = (
        await session.execute(select(func.count()).select_from(base.subquery()))
    ).scalar_one()

    statement = (
        base.order_by(Transaction.date.desc(), Transaction.cree_le.desc())
        .offset(skip)
        .limit(limit)
    )
    result = await session.execute(statement)
    return list(result.all()), total
