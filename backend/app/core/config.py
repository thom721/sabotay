from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    PROJECT_NAME: str = "SabotayPro"
    ENVIRONMENT: str = "development"

    DATABASE_URL: str
    DATABASE_URL_SYNC: str

    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60

    # SMTP (email) — laisser vide en dev : core/notifications.py bascule sur un
    # fallback qui journalise le message au lieu d'échouer.
    SMTP_HOST: str | None = None
    SMTP_PORT: int = 587
    SMTP_USER: str | None = None
    SMTP_PASSWORD: str | None = None
    SMTP_FROM_EMAIL: str | None = None

    # Twilio (SMS) — même fallback si absent.
    TWILIO_ACCOUNT_SID: str | None = None
    TWILIO_AUTH_TOKEN: str | None = None
    TWILIO_FROM_NUMBER: str | None = None

    PASSWORD_RESET_CODE_TTL_MINUTES: int = 15
    PASSWORD_RESET_MAX_ATTEMPTS: int = 5

    # MonCash (paiement mobile Digicel Haïti) — laisser vide en dev, l'endpoint
    # /abonnement/payer renvoie alors 503 tant que les identifiants marchands
    # réels n'ont pas été obtenus.
    MONCASH_CLIENT_ID: str | None = None
    MONCASH_CLIENT_SECRET: str | None = None
    MONCASH_MODE: str = "sandbox"
    ABONNEMENT_MONTANT_HTG: int = 100


settings = Settings()
