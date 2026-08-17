from datetime import date

from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select

import logging

from app.core.notifications import send_email
from app.core.security import generate_temp_password, hash_password
from app.models.client import Client
from app.schemas.client import ClientRead

logger = logging.getLogger("sabotaypro.client")


async def find_duplicate(
    session: AsyncSession,
    *,
    entreprise_id: str,
    nom: str,
    prenom: str,
    date_naissance: date | None,
    nif_cin: str | None,
) -> Client | None:
    """Détecte un client déjà existant dans le même tenant — nif/cin
    identique (souvent absent, donc pas le seul critère possible), ou
    nom + prénom + date de naissance identiques. Comparaison en Python plutôt
    qu'en SQL : le volume par entreprise reste faible et ça évite les
    subtilités de collation Postgres pour un casefold correct."""
    statement = select(Client).where(Client.entreprise_id == entreprise_id)
    result = await session.execute(statement)

    nif_norm = nif_cin.strip().casefold() if nif_cin else None
    nom_norm = nom.strip().casefold()
    prenom_norm = prenom.strip().casefold()

    for candidate in result.scalars().all():
        if nif_norm and candidate.nif_cin and candidate.nif_cin.strip().casefold() == nif_norm:
            return candidate
        if (
            date_naissance is not None
            and candidate.date_naissance == date_naissance
            and candidate.nom.strip().casefold() == nom_norm
            and candidate.prenom.strip().casefold() == prenom_norm
        ):
            return candidate
    return None


async def create(session: AsyncSession, *, entreprise_id: str, data: dict) -> ClientRead:
    client = Client(entreprise_id=entreprise_id, **data)

    temp_password: str | None = None
    if client.email:
        temp_password = generate_temp_password()
        client.hashed_password = hash_password(temp_password)
        client.doit_changer_mot_de_passe = True

    session.add(client)
    await session.commit()
    await session.refresh(client)

    email_envoye = False
    if client.email and temp_password:
        try:
            email_envoye = await send_email(
                client.email,
                "Bienvenue sur votre espace client SabotayPro",
                f"Un compte a été créé pour vous. Identifiant : {client.email}\n"
                f"Mot de passe temporaire : {temp_password}\n"
                "Vous devrez le changer à la première connexion.",
            )
        except Exception:
            logger.exception("Échec d'envoi de l'email de bienvenue pour le client %s", client.id)
            email_envoye = False

    # email_envoye/mot_de_passe_temporaire n'existent pas sur le modèle table
    # Client (SQLModel refuse les attributs hors schéma) : on les porte sur le
    # ClientRead retourné, pour que l'appelant affiche le mot de passe à
    # l'écran quand l'email n'a pas pu être remis — sinon il serait perdu
    # (jamais stocké en clair).
    return ClientRead(
        **client.model_dump(),
        email_envoye=email_envoye,
        mot_de_passe_temporaire=None if email_envoye else temp_password,
    )


async def list_for_tenant(
    session: AsyncSession, *, entreprise_id: str, agent_id: str | None = None
) -> list[Client]:
    statement = select(Client).where(Client.entreprise_id == entreprise_id)
    if agent_id is not None:
        statement = statement.where(Client.agent_assigne_id == agent_id)
    result = await session.execute(statement)
    return list(result.scalars().all())


async def get_for_tenant(
    session: AsyncSession, *, client_id: str, entreprise_id: str
) -> Client | None:
    statement = select(Client).where(
        Client.id == client_id, Client.entreprise_id == entreprise_id
    )
    result = await session.execute(statement)
    return result.scalar_one_or_none()


async def list_by_email(session: AsyncSession, *, email: str) -> list[Client]:
    statement = select(Client).where(Client.email == email).order_by(Client.id)
    result = await session.execute(statement)
    return list(result.scalars().all())


async def assign_agent(
    session: AsyncSession, *, client: Client, agent_assigne_id: str | None
) -> Client:
    client.agent_assigne_id = agent_assigne_id
    session.add(client)
    await session.commit()
    await session.refresh(client)
    return client
