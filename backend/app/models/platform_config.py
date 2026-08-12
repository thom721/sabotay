from sqlmodel import Field, SQLModel


class PlatformConfig(SQLModel, table=True):
    """Réglages globaux de la plateforme — une seule ligne (singleton),
    lue/écrite par le super admin. Extensible à d'autres réglages plus tard."""

    __tablename__ = "platform_config"

    id: int | None = Field(default=None, primary_key=True)
    abonnement_montant_htg: int = Field(default=100)
    # Durée de la période d'essai gratuit (PRD §8.5), en jours à partir de
    # `Entreprise.date_creation` — voir `_abonnement_actif` (transactions.py).
    essai_jours: int = Field(default=14)
