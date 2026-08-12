from datetime import date, timedelta
from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

import app.crud.transaction as crud_transaction
from app.core.db import get_session
from app.core.deps import TenantId, require_roles
from app.models.utilisateur import RoleUtilisateur
from app.schemas.dashboard import DashboardStatistiquesRead, VelociteJournaliereRead

router = APIRouter(prefix="/dashboard", tags=["dashboard"])

SessionDep = Annotated[AsyncSession, Depends(get_session)]


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
