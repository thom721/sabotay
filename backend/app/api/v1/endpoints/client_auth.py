from datetime import datetime, timezone
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import SQLModel

import app.crud.client as crud_client
import app.crud.compte_sabotay as crud_compte
import app.crud.transaction as crud_transaction
from app.core.db import get_session
from app.core.deps import CurrentClient
from app.core.security import create_access_token, hash_password, verify_password
from app.models.client import Client, StatutClient
from app.models.entreprise import Entreprise
from app.schemas.auth import Token
from app.schemas.client import ClientRead
from app.schemas.compte_sabotay import CompteSabotaySolde
from app.schemas.entreprise import EntrepriseRead
from app.schemas.transaction import TransactionRead

router = APIRouter(prefix="/auth", tags=["client-auth"])

SessionDep = Annotated[AsyncSession, Depends(get_session)]

_INVALID_CREDENTIALS_ERROR = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="Email ou mot de passe incorrect",
    headers={"WWW-Authenticate": "Bearer"},
)


class ClientLoginRequest(SQLModel):
    email: str
    password: str


class EntrepriseLieeRead(SQLModel):
    client_id: int
    entreprise_id: int
    entreprise_nom: str
    actif: bool


class SwitchEntrepriseRequest(SQLModel):
    client_id: int


class ClientMotDePasseUpdate(SQLModel):
    mot_de_passe_actuel: str
    nouveau_mot_de_passe: str


class ClientMotDePasseUpdateResponse(SQLModel):
    message: str = "Mot de passe mis à jour"


@router.post("/client-login", response_model=Token)
async def client_login(payload: ClientLoginRequest, session: SessionDep) -> Token:
    candidates = await crud_client.list_by_email(session, email=payload.email)
    matched = [
        candidate
        for candidate in candidates
        if candidate.hashed_password is not None
        and candidate.statut == StatutClient.ACTIF
        and verify_password(payload.password, candidate.hashed_password)
    ]
    if not matched:
        raise _INVALID_CREDENTIALS_ERROR
    client = matched[0]

    client.derniere_connexion = datetime.now(timezone.utc)
    session.add(client)
    await session.commit()

    access_token = create_access_token(
        subject=str(client.id),
        extra_claims={
            "type": "client",
            "entreprise_id": client.entreprise_id,
            "doit_changer_mot_de_passe": client.doit_changer_mot_de_passe,
        },
    )
    return Token(access_token=access_token)


@router.patch("/client/mot-de-passe", response_model=ClientMotDePasseUpdateResponse)
async def update_client_mot_de_passe(
    payload: ClientMotDePasseUpdate,
    session: SessionDep,
    current_client: CurrentClient,
) -> ClientMotDePasseUpdateResponse:
    if current_client.hashed_password is None or not verify_password(
        payload.mot_de_passe_actuel, current_client.hashed_password
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Mot de passe actuel incorrect",
        )

    current_client.hashed_password = hash_password(payload.nouveau_mot_de_passe)
    current_client.doit_changer_mot_de_passe = False
    session.add(current_client)
    await session.commit()
    return ClientMotDePasseUpdateResponse()


moi_router = APIRouter(prefix="/clients", tags=["client-auth"])


@moi_router.get("/moi", response_model=ClientRead)
async def read_current_client(current_client: CurrentClient) -> ClientRead:
    return current_client


@moi_router.get("/moi/entreprises-liees", response_model=list[EntrepriseLieeRead])
async def read_entreprises_liees(
    session: SessionDep, current_client: CurrentClient
) -> list[EntrepriseLieeRead]:
    """Autres comptes Client du même email (autres entreprises) — permet au
    portail Client de proposer un sélecteur d'entreprise sans reconnexion."""
    if current_client.email is None:
        candidates = [current_client]
    else:
        candidates = await crud_client.list_by_email(session, email=current_client.email)

    result: list[EntrepriseLieeRead] = []
    for candidate in candidates:
        if candidate.statut != StatutClient.ACTIF:
            continue
        # Un compte lié ne doit apparaître qu'après une connexion directe au
        # moins une fois (preuve que le client connaît lui-même le mot de
        # passe de CE compte) — sinon un admin d'une autre entreprise pourrait
        # inscrire le même email et se retrouver lié silencieusement, sans
        # consentement du client.
        if candidate.id != current_client.id and candidate.derniere_connexion is None:
            continue
        entreprise = await session.get(Entreprise, candidate.entreprise_id)
        if entreprise is None:
            continue
        result.append(
            EntrepriseLieeRead(
                client_id=candidate.id,
                entreprise_id=candidate.entreprise_id,
                entreprise_nom=entreprise.nom,
                actif=candidate.id == current_client.id,
            )
        )
    return result


@moi_router.post("/moi/switch-entreprise", response_model=Token)
async def switch_entreprise(
    payload: SwitchEntrepriseRequest,
    session: SessionDep,
    current_client: CurrentClient,
) -> Token:
    """Émet un nouveau token pour un autre compte Client lié au même email —
    seule autorisation acceptée : correspondance d'email avec le compte déjà
    authentifié par mot de passe (jamais de confiance dans client_id seul)."""
    target = await session.get(Client, payload.client_id)
    if (
        target is None
        or target.email is None
        or current_client.email is None
        or target.email.lower() != current_client.email.lower()
        or target.statut != StatutClient.ACTIF
        or target.derniere_connexion is None
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Compte lié introuvable"
        )

    target.derniere_connexion = datetime.now(timezone.utc)
    session.add(target)
    await session.commit()

    access_token = create_access_token(
        subject=str(target.id),
        extra_claims={
            "type": "client",
            "entreprise_id": target.entreprise_id,
            "doit_changer_mot_de_passe": target.doit_changer_mot_de_passe,
        },
    )
    return Token(access_token=access_token)


@moi_router.get("/moi/entreprise", response_model=EntrepriseRead)
async def read_entreprise_de_mon_compte(
    session: SessionDep, current_client: CurrentClient
) -> Entreprise:
    """Utilisé pour l'en-tête des reçus imprimés depuis le portail Client —
    GET /entreprises/profil est réservé aux tokens Utilisateur (TenantId),
    un Client a besoin de son propre point d'entrée équivalent."""
    entreprise = await session.get(Entreprise, current_client.entreprise_id)
    if entreprise is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Entreprise introuvable")
    return entreprise


@moi_router.get("/moi/comptes/{compte_id}/solde", response_model=CompteSabotaySolde)
async def read_solde_mon_compte(
    compte_id: int,
    session: SessionDep,
    current_client: CurrentClient,
) -> CompteSabotaySolde:
    compte = await crud_compte.get_for_client(
        session,
        compte_id=compte_id,
        client_id=current_client.id,
        entreprise_id=current_client.entreprise_id,
    )
    if compte is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Compte introuvable")
    return await crud_transaction.get_solde(session, compte=compte)


@moi_router.get("/moi/comptes/{compte_id}/transactions", response_model=list[TransactionRead])
async def read_transactions_mon_compte(
    compte_id: int,
    session: SessionDep,
    current_client: CurrentClient,
) -> list[TransactionRead]:
    compte = await crud_compte.get_for_client(
        session,
        compte_id=compte_id,
        client_id=current_client.id,
        entreprise_id=current_client.entreprise_id,
    )
    if compte is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Compte introuvable")
    return await crud_transaction.list_for_compte(session, compte_id=compte_id)
