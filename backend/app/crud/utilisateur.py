from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import or_, select

import logging

from app.core.notifications import send_email
from app.core.security import generate_temp_password, hash_password
from app.models.utilisateur import RoleUtilisateur, StatutUtilisateur, Utilisateur
from app.schemas.utilisateur import UtilisateurCreate, UtilisateurRead

logger = logging.getLogger("sabotaypro.utilisateur")


async def get_by_telephone_ou_email(
    session: AsyncSession, identifiant: str
) -> Utilisateur | None:
    statement = select(Utilisateur).where(
        or_(Utilisateur.telephone == identifiant, Utilisateur.email == identifiant)
    )
    result = await session.execute(statement)
    return result.scalar_one_or_none()


async def create(
    session: AsyncSession, *, entreprise_id: str, data: UtilisateurCreate
) -> UtilisateurRead:
    temp_password = generate_temp_password()
    utilisateur = Utilisateur(
        entreprise_id=entreprise_id,
        nom=data.nom,
        prenom=data.prenom,
        telephone=data.telephone,
        email=data.email,
        date_naissance=data.date_naissance,
        nif_cin=data.nif_cin,
        adresse=data.adresse,
        hashed_password=hash_password(temp_password),
        doit_changer_mot_de_passe=True,
        role=data.role,
    )
    session.add(utilisateur)
    await session.commit()
    await session.refresh(utilisateur)

    email_envoye = False
    try:
        email_envoye = await send_email(
            utilisateur.email,
            "Bienvenue sur SabotayPro",
            f"Un compte employé a été créé pour vous. Identifiant : {utilisateur.email} "
            f"(ou votre téléphone : {utilisateur.telephone})\n"
            f"Mot de passe temporaire : {temp_password}\n"
            "Vous devrez le changer à la première connexion.",
        )
    except Exception:
        logger.exception("Échec d'envoi de l'email de bienvenue pour l'employé %s", utilisateur.id)
        email_envoye = False

    # email_envoye/mot_de_passe_temporaire n'existent pas sur le modèle table
    # Utilisateur (SQLModel refuse les attributs hors schéma) : on les porte
    # sur l'UtilisateurRead retourné, pour que l'appelant affiche le mot de
    # passe à l'écran quand l'email n'a pas pu être remis — sinon il serait
    # perdu (jamais stocké en clair).
    return UtilisateurRead(
        **utilisateur.model_dump(),
        email_envoye=email_envoye,
        mot_de_passe_temporaire=None if email_envoye else temp_password,
    )


async def list_for_tenant(session: AsyncSession, *, entreprise_id: str) -> list[Utilisateur]:
    statement = select(Utilisateur).where(Utilisateur.entreprise_id == entreprise_id)
    result = await session.execute(statement)
    return list(result.scalars().all())


async def get_for_tenant(
    session: AsyncSession, *, utilisateur_id: str, entreprise_id: str
) -> Utilisateur | None:
    statement = select(Utilisateur).where(
        Utilisateur.id == utilisateur_id, Utilisateur.entreprise_id == entreprise_id
    )
    result = await session.execute(statement)
    return result.scalar_one_or_none()


async def update_statut(
    session: AsyncSession, *, utilisateur: Utilisateur, statut: StatutUtilisateur
) -> Utilisateur:
    utilisateur.statut = statut
    session.add(utilisateur)
    await session.commit()
    await session.refresh(utilisateur)
    return utilisateur


async def update_role(
    session: AsyncSession, *, utilisateur: Utilisateur, role: RoleUtilisateur
) -> Utilisateur:
    utilisateur.role = role
    session.add(utilisateur)
    await session.commit()
    await session.refresh(utilisateur)
    return utilisateur
