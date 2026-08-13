from typing import Any

from sqlmodel import SQLModel


class SetupStatutRead(SQLModel):
    installation_terminee: bool
    entreprise_nom: str | None


class SetupConnecterRequest(SQLModel):
    code: str
    cloud_url: str


class SetupConnecterResponse(SQLModel):
    installation_terminee: bool
    resultat_sync: dict[str, Any]
