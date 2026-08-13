from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from sqlmodel import select

from app.core.db import get_session
from app.core.deps import TenantId, require_roles
from app.core.security import hash_password
from app.crud.utilisateur import get_by_telephone_ou_email
from app.models.abonnement import Abonnement
from app.models.code_installation import CodeInstallation, generer_code_installation
from app.models.entreprise import Entreprise
from app.models.utilisateur import RoleUtilisateur, Utilisateur
from app.schemas.code_installation import CodeInstallationRead
from app.schemas.entreprise import EntrepriseProfilUpdate, EntrepriseRead, EntrepriseRegister

router = APIRouter(prefix="/entreprises", tags=["entreprises"])


@router.post("/register", response_model=EntrepriseRead, status_code=status.HTTP_201_CREATED)
async def register_entreprise(
    payload: EntrepriseRegister,
    session: Annotated[AsyncSession, Depends(get_session)],
) -> Entreprise:
    """Inscription self-service d'une entreprise + premier compte Admin (PRD §7.1)."""
    existing = await get_by_telephone_ou_email(session, payload.admin_telephone)
    if existing is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Ce numéro de téléphone est déjà associé à un compte",
        )

    entreprise = Entreprise(nom=payload.nom_entreprise, devise=payload.devise)
    session.add(entreprise)
    await session.flush()  # obtient entreprise.id sans commit

    admin = Utilisateur(
        entreprise_id=entreprise.id,
        nom=payload.admin_nom,
        telephone=payload.admin_telephone,
        email=payload.admin_email,
        hashed_password=hash_password(payload.admin_password),
        role=RoleUtilisateur.ADMIN,
    )
    session.add(admin)

    abonnement = Abonnement(entreprise_id=entreprise.id, date_debut=date.today())
    session.add(abonnement)

    await session.commit()
    await session.refresh(entreprise)
    return entreprise


@router.get(
    "/code-installation",
    response_model=CodeInstallationRead,
    dependencies=[Depends(require_roles(RoleUtilisateur.ADMIN))],
)
async def lire_code_installation(
    session: Annotated[AsyncSession, Depends(get_session)],
    entreprise_id: TenantId,
) -> CodeInstallation:
    """Code d'installation courant (généré à la demande s'il n'existe pas
    encore) pour lier un poste local au cloud sans email/mot de passe —
    saisi dans l'assistant d'installation bureau (Epic 5). Une fois utilisé,
    reste affiché tel quel (`utilise=True`) ; régénérer via POST invalide
    l'ancien."""
    statement = select(CodeInstallation).where(
        CodeInstallation.entreprise_id == entreprise_id, CodeInstallation.utilise == False  # noqa: E712
    )
    code = (await session.execute(statement)).scalars().first()
    if code is None:
        code = CodeInstallation(
            entreprise_id=entreprise_id, code=generer_code_installation()
        )
        session.add(code)
        await session.commit()
        await session.refresh(code)
    return code


@router.post(
    "/code-installation",
    response_model=CodeInstallationRead,
    dependencies=[Depends(require_roles(RoleUtilisateur.ADMIN))],
)
async def regenerer_code_installation(
    session: Annotated[AsyncSession, Depends(get_session)],
    entreprise_id: TenantId,
) -> CodeInstallation:
    """Invalide le(s) code(s) non utilisé(s) existant(s) et en génère un
    nouveau — les codes déjà consommés (`utilise=True`) restent en base pour
    l'historique mais ne sont jamais réaffichés/réutilisables."""
    statement = select(CodeInstallation).where(
        CodeInstallation.entreprise_id == entreprise_id, CodeInstallation.utilise == False  # noqa: E712
    )
    anciens = (await session.execute(statement)).scalars().all()
    for ancien in anciens:
        await session.delete(ancien)

    code = CodeInstallation(entreprise_id=entreprise_id, code=generer_code_installation())
    session.add(code)
    await session.commit()
    await session.refresh(code)
    return code


@router.get("/profil", response_model=EntrepriseRead)
async def read_profil_entreprise(
    session: Annotated[AsyncSession, Depends(get_session)],
    entreprise_id: TenantId,
) -> Entreprise:
    """Consultation du profil de l'entreprise du tenant courant."""
    entreprise = await session.get(Entreprise, entreprise_id)
    if entreprise is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Entreprise introuvable"
        )
    return entreprise


@router.patch(
    "/profil",
    response_model=EntrepriseRead,
    dependencies=[Depends(require_roles(RoleUtilisateur.ADMIN))],
)
async def update_profil_entreprise(
    payload: EntrepriseProfilUpdate,
    session: Annotated[AsyncSession, Depends(get_session)],
    entreprise_id: TenantId,
) -> Entreprise:
    """Mise à jour partielle du profil entreprise (Admin uniquement)."""
    entreprise = await session.get(Entreprise, entreprise_id)
    if entreprise is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Entreprise introuvable"
        )

    update_data = payload.model_dump(exclude_unset=True, exclude_none=True)
    for field, value in update_data.items():
        setattr(entreprise, field, value)

    session.add(entreprise)
    await session.commit()
    await session.refresh(entreprise)
    return entreprise
