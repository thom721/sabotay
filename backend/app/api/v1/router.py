from fastapi import APIRouter

from app.api.v1.endpoints import (
    abonnement,
    auth,
    client_auth,
    clients,
    comptes,
    dashboard,
    entreprises,
    password_reset,
    superadmin,
    superadmin_auth,
    transactions,
    utilisateurs,
)

api_router = APIRouter()
api_router.include_router(auth.router)
api_router.include_router(client_auth.router)
api_router.include_router(client_auth.moi_router)
api_router.include_router(password_reset.router)
api_router.include_router(entreprises.router)
api_router.include_router(utilisateurs.router)
api_router.include_router(clients.router)
api_router.include_router(comptes.router)
api_router.include_router(transactions.router)
api_router.include_router(dashboard.router)
api_router.include_router(abonnement.router)
api_router.include_router(superadmin_auth.router)
api_router.include_router(superadmin.router)
