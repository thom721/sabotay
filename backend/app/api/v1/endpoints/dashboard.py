from datetime import date, timedelta
from decimal import Decimal
from enum import StrEnum
from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select

import app.crud.transaction as crud_transaction
from app.core.db import get_session
from app.core.deps import TenantId, require_roles
from app.models.client import Client
from app.models.transaction import TypeTransaction
from app.models.utilisateur import RoleUtilisateur
from app.schemas.dashboard import (
    DashboardStatistiquesRead,
    PointSerieTemporelleRead,
    SerieTemporelleRead,
    VelociteJournaliereRead,
)

router = APIRouter(prefix="/dashboard", tags=["dashboard"])

SessionDep = Annotated[AsyncSession, Depends(get_session)]

_MOIS_ABREGES = [
    "Jan", "Fév", "Mar", "Avr", "Mai", "Jun",
    "Jul", "Aoû", "Sep", "Oct", "Nov", "Déc",
]


class PeriodeSerie(StrEnum):
    JOUR = "jour"
    SEMAINE = "semaine"
    MOIS = "mois"
    ANNEE = "annee"


@router.get(
    "/statistiques",
    response_model=DashboardStatistiquesRead,
    dependencies=[Depends(require_roles(RoleUtilisateur.ADMIN, RoleUtilisateur.MANAGER))],
)
async def read_dashboard_statistiques(
    session: SessionDep, entreprise_id: TenantId
) -> DashboardStatistiquesRead:
    """Agrégats tenant pour le tableau de bord gestionnaire : collecte du
    mois en cours, vélocité des 7 derniers jours et transactions récentes."""
    aujourdhui = date.today()
    debut_mois = aujourdhui.replace(day=1)
    debut_semaine = aujourdhui - timedelta(days=6)

    montant_mois, nb_transactions_mois = await crud_transaction.get_statistiques_mois(
        session, entreprise_id=entreprise_id, debut_mois=debut_mois
    )

    velocite_par_date = dict(
        await crud_transaction.get_velocite_journaliere(
            session, entreprise_id=entreprise_id, date_debut=debut_semaine, date_fin=aujourdhui
        )
    )
    velocite_7_jours = [
        VelociteJournaliereRead(
            date=jour,
            montant_collecte=velocite_par_date.get(jour, 0),
        )
        for jour in (debut_semaine + timedelta(days=i) for i in range(7))
    ]

    transactions_recentes = await crud_transaction.list_recent_for_tenant(
        session, entreprise_id=entreprise_id, limit=10
    )

    return DashboardStatistiquesRead(
        montant_collecte_mois=montant_mois,
        nb_transactions_payees_mois=nb_transactions_mois,
        velocite_7_jours=velocite_7_jours,
        transactions_recentes=transactions_recentes,
    )


def _ajouter_mois(d: date, n: int) -> date:
    mois_index = d.month - 1 + n
    annee = d.year + mois_index // 12
    mois = mois_index % 12 + 1
    return date(annee, mois, 1)


def _bornes_buckets(periode: PeriodeSerie, aujourdhui: date) -> list[tuple[date, date, str]]:
    """Liste de (début inclus, fin exclue, label) — du plus ancien au plus
    récent. jour/semaine sont des fenêtres glissantes de largeur fixe ;
    mois/année sont alignées sur le calendrier (plus lisible : "Août 2026"
    plutôt qu'une fenêtre glissante de 30 jours arbitraire)."""
    if periode == PeriodeSerie.JOUR:
        return [
            (
                aujourdhui - timedelta(days=13 - i),
                aujourdhui - timedelta(days=12 - i),
                (aujourdhui - timedelta(days=13 - i)).strftime("%d/%m"),
            )
            for i in range(14)
        ]
    if periode == PeriodeSerie.SEMAINE:
        return [
            (
                aujourdhui - timedelta(days=(7 - i) * 7 - 1),
                aujourdhui - timedelta(days=(6 - i) * 7 - 1),
                (aujourdhui - timedelta(days=(7 - i) * 7 - 1)).strftime("%d/%m"),
            )
            for i in range(8)
        ]
    if periode == PeriodeSerie.MOIS:
        debut_mois_courant = aujourdhui.replace(day=1)
        mois = [_ajouter_mois(debut_mois_courant, -i) for i in range(11, -1, -1)]
        return [
            (m, _ajouter_mois(m, 1), f"{_MOIS_ABREGES[m.month - 1]} {m.year}")
            for m in mois
        ]
    # ANNEE
    annees = [aujourdhui.year - i for i in range(4, -1, -1)]
    return [(date(a, 1, 1), date(a + 1, 1, 1), str(a)) for a in annees]


@router.get(
    "/serie-temporelle",
    response_model=SerieTemporelleRead,
    dependencies=[Depends(require_roles(RoleUtilisateur.ADMIN, RoleUtilisateur.MANAGER))],
)
async def read_serie_temporelle(
    session: SessionDep, entreprise_id: TenantId, periode: PeriodeSerie = PeriodeSerie.MOIS
) -> SerieTemporelleRead:
    """Montants collectés/retirés et nouveaux clients, groupés par bucket
    (jour/semaine/mois/année) — pour le graphique du tableau de bord."""
    aujourdhui = date.today()
    buckets = _bornes_buckets(periode, aujourdhui)

    transactions = await crud_transaction.list_for_periode(
        session,
        entreprise_id=entreprise_id,
        date_debut=buckets[0][0],
        date_fin=buckets[-1][1] - timedelta(days=1),
    )

    clients_result = await session.execute(
        select(Client.date_creation).where(
            Client.entreprise_id == entreprise_id,
            Client.date_creation >= buckets[0][0],
        )
    )
    dates_creation_clients = [row[0].date() for row in clients_result.all()]

    points: list[PointSerieTemporelleRead] = []
    for debut, fin, label in buckets:
        montant_collecte = Decimal(0)
        montant_retrait = Decimal(0)
        for t in transactions:
            if debut <= t.date < fin:
                if t.type == TypeTransaction.COLLECTE:
                    montant_collecte += t.montant
                else:
                    montant_retrait += t.montant
        nb_nouveaux_clients = sum(1 for d in dates_creation_clients if debut <= d < fin)
        points.append(
            PointSerieTemporelleRead(
                label=label,
                montant_collecte=montant_collecte,
                montant_retrait=montant_retrait,
                nb_nouveaux_clients=nb_nouveaux_clients,
            )
        )

    return SerieTemporelleRead(points=points)
