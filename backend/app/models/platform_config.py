import uuid

from sqlmodel import Field, SQLModel


class PlatformConfig(SQLModel, table=True):
    """Réglages globaux de la plateforme — une seule ligne (singleton),
    lue/écrite par le super admin. Extensible à d'autres réglages plus tard."""

    __tablename__ = "platform_config"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    abonnement_montant_htg: int = Field(default=100)
    # Prix appliqué au PROCHAIN renouvellement — distinct de
    # abonnement_montant_htg pour annoncer un changement de prix à l'avance
    # (visible sur la page Abonnement du client, à côté de la date de
    # renouvellement) avant qu'il ne soit effectivement facturé. None =
    # aucun changement annoncé, le renouvellement se fait au même prix que
    # abonnement_montant_htg (voir abonnement.py::_montant_renouvellement).
    abonnement_renouvellement_htg: int | None = Field(default=None)
    # Durée de la période d'essai gratuit (PRD §8.5), en jours à partir de
    # `Entreprise.date_creation` — voir `_abonnement_actif` (transactions.py).
    essai_jours: int = Field(default=14)

    # Configuration email SMTP dynamique — éditable par le super-admin
    # (Paramètres → Email), lue par core/notifications.py::send_email() au
    # lieu des valeurs statiques .env (settings.SMTP_*, gardées en repli si
    # ces champs sont vides). Même principe que PlatformConfig.smtp_* de
    # pos_api : source de vérité en base, pas dans la config de déploiement.
    smtp_host: str | None = Field(default=None)
    smtp_port: int = Field(default=587)
    smtp_user: str | None = Field(default=None)
    smtp_password: str | None = Field(default=None)
    smtp_from_email: str | None = Field(default=None)
