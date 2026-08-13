from datetime import datetime
from zoneinfo import ZoneInfo

HAITI_TZ = ZoneInfo("America/Port-au-Prince")


def now_local() -> datetime:
    """Heure actuelle naïve en heure locale Haïti (America/Port-au-Prince).

    Utilisé pour tous les champs DateTime métier (date_creation/cree_le,
    updated_at, derniere_connexion, date_paiement, date_expiration...) —
    création ET modification, sans exception, dans les modèles comme dans
    le code d'endpoint. Même choix que pos_api (`DateTime(timezone=False)`
    + `now_local()`) : SQLite (mode local) ne préserve pas le fuseau
    horaire aussi strictement que Postgres — comparer un datetime aware et
    un naïf lève `TypeError`. En restant naïf partout, avec une seule
    convention (Haïti local, pas UTC — cohérent avec
    `Entreprise.fuseau_horaire`, déjà "America/Port-au-Prince" par défaut),
    le problème disparaît structurellement plutôt que d'être corrigé au
    cas par cas.
    """
    return datetime.now(HAITI_TZ).replace(tzinfo=None)
