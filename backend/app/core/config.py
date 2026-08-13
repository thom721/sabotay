import os
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

ENV_FILE_PATH = Path(".env")


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    PROJECT_NAME: str = "SabotayPro"
    ENVIRONMENT: str = "development"

    # Optionnelles : non nécessaires quand LOCAL_MODE=True (SQLite dérivé de
    # LOCAL_DATABASE_PATH à la place) — voir core/db.py.
    DATABASE_URL: str | None = None
    DATABASE_URL_SYNC: str | None = None

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

    # Clé privée Ed25519 (base64, 32 octets) utilisée pour signer le blob de
    # licence (GET /abonnement/licence) — vérifié côté client sans réseau
    # avec la clé publique correspondante embarquée dans web/ et mobile/.
    # Générée une fois via backend/scripts/generate_licence_keypair.py.
    # Laisser vide en dev désactive simplement l'endpoint (503).
    LICENCE_PRIVATE_KEY: str | None = None

    # Mode local (Phase 2a) — cette même codebase tourne soit comme backend
    # cloud multi-tenant (LOCAL_MODE=False, défaut), soit comme serveur
    # mono-tenant sur le poste d'un client (LOCAL_MODE=True), SQLite au lieu
    # de Postgres, qui se synchronise avec le cloud plutôt que de servir de
    # source de vérité. Ne jamais régler LICENCE_PRIVATE_KEY sur une
    # installation locale — la clé privée ne doit exister que côté cloud.
    LOCAL_MODE: bool = False
    LOCAL_DATABASE_PATH: str = "./sabotay_local.db"
    CLOUD_SYNC_URL: str | None = None
    CLOUD_SYNC_TOKEN: str | None = None
    DEVICE_ID: str = "self"

    # Uniquement utilisés par server_main.py (binaire desktop compilé) — le
    # `uvicorn app.main:app` du développement passe par sa propre CLI et
    # ignore ces valeurs.
    SERVER_HOST: str = "127.0.0.1"
    # 9004, pas 9003 (pos_api) — distinct pour ne jamais entrer en conflit si
    # les deux produits sont un jour installés sur le même poste.
    SERVER_PORT: int = 9004

    # Origines autorisées en CORS — "*" par défaut (dev : Flutter web tourne
    # sur un port différent du backend). En déploiement réel
    # (deploiement/docker-compose.yml), régler sur le(s) domaine(s) exact(s)
    # séparés par des virgules, ex. "https://sabotay.infini-software.cloud".
    CORS_ORIGINS: str = "*"

    @property
    def cors_origins_list(self) -> list[str]:
        if self.CORS_ORIGINS == "*":
            return ["*"]
        return [origin.strip() for origin in self.CORS_ORIGINS.split(",") if origin.strip()]


settings = Settings()


def update_env_file(updates: dict[str, str]) -> None:
    """Met à jour (ou ajoute) des clés dans le fichier .env sur disque —
    utilisé uniquement par `POST /setup/connecter` (mode local) pour
    persister `CLOUD_SYNC_URL`/`CLOUD_SYNC_TOKEN` reçus après l'échange d'un
    code d'installation, afin que la liaison survive à un redémarrage du
    service. Même rôle que `write_ini_config()` de pos_api, adapté au format
    `.env` (KEY=VALUE) au lieu d'un `.ini` à sections.

    Ne met à jour que le fichier sur disque — appelant responsable de
    répercuter les mêmes valeurs sur l'objet `settings` en mémoire
    (`Settings` reste un objet Python mutable ordinaire après instanciation)."""
    lines = ENV_FILE_PATH.read_text(encoding="utf-8").splitlines() if ENV_FILE_PATH.exists() else []

    remaining = dict(updates)
    new_lines = []
    for line in lines:
        stripped = line.strip()
        key = stripped.split("=", 1)[0].strip() if "=" in stripped and not stripped.startswith("#") else None
        if key in remaining:
            new_lines.append(f"{key}={remaining.pop(key)}")
        else:
            new_lines.append(line)
    for key, value in remaining.items():
        new_lines.append(f"{key}={value}")

    ENV_FILE_PATH.write_text("\n".join(new_lines) + "\n", encoding="utf-8")

    # Windows : le fichier contient désormais un jeton de sync longue durée
    # (365 jours) — même restriction que pos_server.ini côté pos_api (lecture
    # réservée à SYSTEM + Administrators, pas à n'importe quel compte
    # utilisateur du poste).
    if os.name == "nt":
        import subprocess

        try:
            subprocess.run(
                [
                    "icacls", str(ENV_FILE_PATH.resolve()),
                    "/inheritance:r",
                    "/grant", "SYSTEM:(F)",
                    "/grant", "Administrators:(F)",
                ],
                capture_output=True,
                timeout=5,
            )
        except Exception:
            pass
