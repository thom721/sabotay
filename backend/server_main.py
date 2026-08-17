#!/usr/bin/env python3
"""
SabotayPro Server — point d'entrée pour la compilation Nuitka.

Utilisation normale  :  python server_main.py
Binaire compilé      :  ./sabotaypro-server  (ou .exe sur Windows)

Calqué sur server_main.py de pos_api (même pipeline Nuitka, même stratégie
de log de crash sans console) — voir /development/pos_api/server_main.py.
"""
import os
import sys
import pathlib
import argparse

# ── Imports explicites pour Nuitka ────────────────────────────────────────────
# SQLAlchemy charge psycopg/aiosqlite dynamiquement via le schéma de
# DATABASE_URL ("postgresql+psycopg://" / "sqlite+aiosqlite://"), passlib
# charge ses handlers dynamiquement, etc. Sans ces imports ici, Nuitka ne les
# inclut pas dans le binaire standalone (piège déjà rencontré côté pos_api).
import psycopg            # noqa: F401
import aiosqlite          # noqa: F401
import alembic             # noqa: F401
import passlib             # noqa: F401
import passlib.handlers    # noqa: F401 - chargé dynamiquement par passlib.context
import passlib.handlers.bcrypt  # noqa: F401
import bcrypt               # noqa: F401
import jose                 # noqa: F401
import cryptography         # noqa: F401 - signature/vérification Ed25519 (core/licence.py)
import multipart            # noqa: F401
import aiosmtplib           # noqa: F401
import dotenv                 # noqa: F401
# twilio délibérément PAS importé ici (contrairement aux autres) — exclu du
# binaire compilé via --nofollow-import-to=twilio (build.yml) : son SDK
# (630 fichiers, ~26 Mo) ajoutait 20-30+ min au temps de build Nuitka pour un
# canal déjà secondaire (SMS, jamais configuré en prod depuis l'Epic 16).
# Repli géré par core/notifications.py::send_sms si jamais reconfiguré quand
# même sur un poste bureau (ModuleNotFoundError attrapée, pas un crash).


def _fix_workdir() -> None:
    """Bascule le CWD vers le dossier du binaire quand compilé avec Nuitka —
    important ici car LOCAL_DATABASE_PATH (SQLite local) est un chemin
    relatif (voir app/core/db.py)."""
    try:
        _ = __compiled__   # noqa: F821 — builtin Nuitka uniquement
        exe_dir = pathlib.Path(sys.executable).parent.resolve()
        os.chdir(exe_dir)
    except NameError:
        pass  # mode source normal


def _crash_log_dir() -> pathlib.Path:
    if sys.platform == "win32":
        base = os.environ.get("PROGRAMDATA") or r"C:\ProgramData"
        return pathlib.Path(base) / "SabotayPro"
    if sys.platform == "darwin":
        return pathlib.Path.home() / "Library" / "Application Support" / "SabotayPro"
    return pathlib.Path.home() / ".sabotaypro"


def _crash_log_path() -> pathlib.Path:
    try:
        log_dir = _crash_log_dir()
        log_dir.mkdir(parents=True, exist_ok=True)
        return log_dir / "sabotaypro-crash.log"
    except Exception:
        return pathlib.Path(sys.executable).parent / "sabotaypro-crash.log"


def _write_crash_log(tb_text: str) -> str:
    import datetime
    log_path = _crash_log_path()
    with open(log_path, "a", encoding="utf-8") as f:
        f.write(f"\n{'=' * 60}\n")
        f.write(f"CRASH {datetime.datetime.now().isoformat()}\n")
        f.write(tb_text)
    return str(log_path)


def _build_log_config() -> tuple[dict, "pathlib.Path"]:
    """Journal permanent (pas seulement le crash log ci-dessus) — le
    service tourne en session 0 sous Windows, sans console visible : sans
    ce fichier, un service qui ne démarre pas ou ne répond pas ne laisse
    strictement aucune trace pour comprendre pourquoi après coup (poste
    bureau, cas réel rencontré : app bloquée sur l'assistant "Connecter ce
    poste au cloud" faute de savoir si le serveur tournait vraiment).

    Capture aussi bien les logs applicatifs (`uvicorn.error`) que les
    requêtes reçues (`uvicorn.access`) — permet de distinguer "le serveur
    n'a jamais démarré" de "le serveur tourne mais ne reçoit aucune requête"
    (pare-feu, mauvais port) de "les requêtes arrivent mais échouent".

    Construit un dict `log_config` complet (plutôt que d'appeler
    logging.getLogger(...).addHandler(...) avant coup) car uvicorn.run()
    applique lui-même logging.config.dictConfig() sur les loggers
    "uvicorn"/"uvicorn.error"/"uvicorn.access" au démarrage — n'importe
    quel handler ajouté avant serait simplement écrasé."""
    import copy
    from uvicorn.config import LOGGING_CONFIG

    log_dir = _crash_log_dir()
    log_dir.mkdir(parents=True, exist_ok=True)
    log_path = log_dir / "sabotaypro-server.log"

    config = copy.deepcopy(LOGGING_CONFIG)
    config["formatters"]["file"] = {
        "()": "logging.Formatter",
        "fmt": "%(asctime)s %(levelname)s %(name)s: %(message)s",
    }
    config["handlers"]["file"] = {
        "class": "logging.handlers.RotatingFileHandler",
        "formatter": "file",
        "filename": str(log_path),
        "maxBytes": 2_000_000,
        "backupCount": 3,
        "encoding": "utf-8",
    }
    # Seuls "uvicorn.error"/"uvicorn.access" reçoivent le handler fichier —
    # "uvicorn.error" propage déjà vers le logger parent "uvicorn" (pas de
    # "propagate": False dessus dans LOGGING_CONFIG) : l'ajouter aussi à
    # "uvicorn" ferait écrire chaque ligne deux fois dans le fichier.
    for logger_name in ("uvicorn.error", "uvicorn.access"):
        config["loggers"].setdefault(logger_name, {}).setdefault("handlers", [])
        config["loggers"][logger_name]["handlers"].append("file")
    config["loggers"]["sabotaypro"] = {"handlers": ["file"], "level": "INFO", "propagate": False}

    return config, log_path


def _show_crash_popup(log_path: str, summary: str) -> None:
    # MessageBoxW ne fonctionne pas depuis un service Windows (session 0
    # isolée) — tenté quand même : marche si l'exe est lancé manuellement,
    # échoue silencieusement sinon.
    if sys.platform != "win32":
        return
    try:
        import ctypes
        ctypes.windll.user32.MessageBoxW(  # type: ignore[attr-defined]
            0,
            f"Le serveur n'a pas pu démarrer :\n\n{summary}\n\nDétails dans :\n{log_path}",
            "SabotayPro — Erreur de démarrage",
            0x10,  # MB_ICONERROR
        )
    except Exception:
        pass


def main() -> None:
    _fix_workdir()

    import logging
    import logging.config
    log_config, log_path = _build_log_config()
    logging.config.dictConfig(log_config)
    logger = logging.getLogger("sabotaypro")
    logger.info("Démarrage du serveur SabotayPro (pid=%s, argv=%s)", os.getpid(), sys.argv[1:])

    parser = argparse.ArgumentParser(description="SabotayPro – Serveur local")
    parser.add_argument("--host", default="", help="Adresse d'écoute (défaut: settings.SERVER_HOST)")
    parser.add_argument("--port", type=int, default=0, help="Port d'écoute (défaut: settings.SERVER_PORT)")
    parser.add_argument("--reload", action="store_true", help="Rechargement auto (développement)")
    args = parser.parse_args()

    try:
        from app.core.config import settings
        from app.main import app
    except BaseException:
        logger.exception("Échec pendant l'import de la configuration/app — le serveur ne démarrera pas")
        raise

    host = args.host or settings.SERVER_HOST
    port = args.port or settings.SERVER_PORT
    logger.info(
        "Configuration chargée — écoute prévue sur %s:%s (LOCAL_MODE=%s), journal: %s",
        host, port, getattr(settings, "LOCAL_MODE", "?"), log_path,
    )

    import uvicorn
    try:
        uvicorn.run(
            "app.main:app" if args.reload else app,
            host=host,
            port=port,
            log_level="info",
            # None = uvicorn n'appelle PAS dictConfig lui-même — sinon il
            # réapplique log_config une 2e fois (déjà fait ci-dessus) et
            # crée un second RotatingFileHandler, doublant chaque ligne.
            log_config=None,
            reload=args.reload,
        )
    finally:
        logger.info("Arrêt du serveur SabotayPro")


if __name__ == "__main__":
    try:
        main()
    except BaseException as _exc:
        # BaseException attrape aussi SystemExit (levé par uvicorn sur erreur
        # de port, etc.) — on ignore SystemExit(0) = arrêt propre.
        if isinstance(_exc, SystemExit) and _exc.code == 0:
            sys.exit(0)
        import traceback
        tb = traceback.format_exc()
        log_path = _write_crash_log(tb)
        summary = tb.strip().splitlines()[-1] if tb.strip() else "Erreur inconnue"
        print(f"\n{'='*60}\nCRASH: {summary}\nLog: {log_path}\n{'='*60}\n", flush=True)
        _show_crash_popup(log_path, summary)
        # Garder la console ouverte pour lire l'erreur (mode interactif uniquement)
        try:
            if sys.stdin and sys.stdin.isatty():
                input("Appuyez sur Entrée pour fermer...")
        except Exception:
            pass
        sys.exit(getattr(_exc, "code", 1) or 1)
