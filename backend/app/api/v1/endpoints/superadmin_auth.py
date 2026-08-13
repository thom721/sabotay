from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import SQLModel, func, select

from app.core.config import settings
from app.core.db import get_session
from app.core.dt_utils import now_local
from app.core.security import create_access_token, hash_password, verify_password
from app.models.super_admin import SuperAdmin
from app.schemas.auth import Token
from app.schemas.superadmin import SuperAdminBootstrapStatut, SuperAdminCompteCreate, SuperAdminCompteRead

router = APIRouter(prefix="/auth", tags=["superadmin-auth"])

SessionDep = Annotated[AsyncSession, Depends(get_session)]

_INVALID_CREDENTIALS_ERROR = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="Email ou mot de passe incorrect",
    headers={"WWW-Authenticate": "Bearer"},
)


class SuperAdminLoginRequest(SQLModel):
    email: str
    password: str


@router.post("/superadmin-login", response_model=Token)
async def superadmin_login(payload: SuperAdminLoginRequest, session: SessionDep) -> Token:
    statement = select(SuperAdmin).where(SuperAdmin.email == payload.email)
    result = await session.execute(statement)
    super_admin = result.scalar_one_or_none()

    if (
        super_admin is None
        or not verify_password(payload.password, super_admin.hashed_password)
        or super_admin.statut != "actif"
    ):
        raise _INVALID_CREDENTIALS_ERROR

    super_admin.derniere_connexion = now_local()
    session.add(super_admin)
    await session.commit()

    access_token = create_access_token(
        subject=str(super_admin.id),
        extra_claims={"type": "superadmin"},
    )
    return Token(access_token=access_token)


@router.get("/superadmin-bootstrap", response_model=SuperAdminBootstrapStatut)
async def lire_statut_bootstrap(session: SessionDep) -> SuperAdminBootstrapStatut:
    """Indique si la création du tout premier compte super-admin est encore
    possible — vrai uniquement tant qu'aucun compte n'existe. Permet au web
    de proposer cet écran au premier déploiement cloud plutôt que l'écran de
    connexion habituel (Admin → Entreprise n'a pas encore de super-admin à
    ce stade). Même principe que `_is_setup_done()` de pos_api et que
    `/setup/statut` (Epic 5f) : dérivé des données réelles, jamais rouvert
    une fois un compte créé.

    Toujours `necessaire=False` en mode local : `super_admins` n'y est
    jamais peuplé (donnée de plateforme, jamais synchronisée vers un poste
    local, voir ENTITES dans sync.py) — sans ce garde-fou, un poste bureau
    fraîchement installé répondrait toujours `True` et proposerait de créer
    un "super-admin" local fantôme, sans aucun sens sur une installation
    mono-tenant. Le web (`superAdminBootstrapNecessaireProvider`) applique
    déjà ce même filtre côté client ; ceci le garantit aussi côté serveur."""
    if settings.LOCAL_MODE:
        return SuperAdminBootstrapStatut(necessaire=False)
    count = (await session.execute(select(func.count()).select_from(SuperAdmin))).scalar_one()
    return SuperAdminBootstrapStatut(necessaire=count == 0)


@router.post(
    "/superadmin-bootstrap",
    response_model=SuperAdminCompteRead,
    status_code=status.HTTP_201_CREATED,
)
async def creer_premier_super_admin(
    payload: SuperAdminCompteCreate, session: SessionDep
) -> SuperAdmin:
    """Crée le tout premier compte super-admin — verrouillé définitivement
    dès qu'un compte existe déjà (403), contrairement à
    `POST /superadmin/comptes` qui reste ouvert en continu mais exige déjà
    d'être authentifié en tant que super-admin (impossible au tout premier
    déploiement, personne n'existe encore pour s'y connecter).

    Jamais disponible en mode local — voir le même garde-fou et sa
    justification sur `GET /auth/superadmin-bootstrap` ci-dessus."""
    if settings.LOCAL_MODE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le bootstrap super-admin n'est disponible que sur le cloud",
        )
    count = (await session.execute(select(func.count()).select_from(SuperAdmin))).scalar_one()
    if count > 0:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Un compte super-admin existe déjà — réservé au premier déploiement",
        )

    super_admin = SuperAdmin(
        nom=payload.nom, email=payload.email, hashed_password=hash_password(payload.password)
    )
    session.add(super_admin)
    await session.commit()
    await session.refresh(super_admin)
    return super_admin
