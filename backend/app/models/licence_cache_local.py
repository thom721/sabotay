import uuid
from datetime import datetime

from sqlmodel import Field, SQLModel

from app.core.dt_utils import now_local


class LicenceCacheLocal(SQLModel, table=True):
    """Cache local (poste bureau uniquement, `LOCAL_MODE=true`) du dernier
    blob de licence vérifié — permet à `_abonnement_actif()`
    (transactions.py) de fonctionner hors-ligne, puisque `abonnements` n'est
    jamais synchronisé vers un poste local (voir `ENTITES` dans sync.py, et
    la clé privée de licence n'existe que côté cloud). Rafraîchi par la
    boucle de sync périodique (main.py) et par `POST /setup/connecter`.
    Singleton, comme `PlatformConfig`."""

    __tablename__ = "licence_cache_local"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    # JSON du payload déjà vérifié (Ed25519) au moment de l'écriture — voir
    # core/licence.py::rafraichir_cache_local. Jamais réécrit avec un blob
    # non vérifié.
    payload_json: str
    fetched_at: datetime = Field(default_factory=now_local)
