import secrets
import uuid
from datetime import datetime

from sqlmodel import Field, SQLModel

from app.core.dt_utils import now_local

# Alphabet sans ambiguïté visuelle (pas de 0/O, 1/I) — même choix que
# pos_api (Helper/InstallationCode côté cloud).
_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"


def generer_code_installation() -> str:
    """Génère un code lisible du type ABCD-EFGH-IJKL."""
    return "-".join(
        "".join(secrets.choice(_ALPHABET) for _ in range(4)) for _ in range(3)
    )


class CodeInstallation(SQLModel, table=True):
    """Code d'installation bureau — alternative à l'email/mot de passe pour
    lier un poste local au cloud (`POST /sync/redeem-code`), même pattern que
    pos_api (`InstallationCode`). Contrairement à pos_api, pas de notion de
    dépôt/warehouse ici : un code est directement scoped à l'entreprise (un
    seul poste local par entreprise, voir Epic 2 dans EPICS.md) — la
    consommation marque directement `utilise=True`, pas d'étape de "claim"
    séparée, il n'y a rien d'autre à réclamer."""

    __tablename__ = "codes_installation"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    code: str = Field(unique=True, index=True)
    entreprise_id: str = Field(foreign_key="entreprises.id", index=True)
    cree_le: datetime = Field(default_factory=now_local)
    utilise: bool = Field(default=False)
    utilise_le: datetime | None = Field(default=None)
