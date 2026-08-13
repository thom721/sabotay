"""
SabotayPro — Service système cross-platform.

Windows : python service_wrapper.py install | start | stop | remove | status
macOS   : python service_wrapper.py install | start | stop | remove | status

Calqué sur service_wrapper.py de pos_api — voir
/development/pos_api/service_wrapper.py. Sabotay ne cible que Windows +
macOS pour le premier jet (voir EPICS.md Epic 5), pas de branche Linux.
"""
import sys
import subprocess
import platform
from pathlib import Path

SERVICE_NAME = "SabotayProServer"
SERVICE_DISPLAY = "SabotayPro Server"
SERVICE_DESC = "Serveur API local pour SabotayPro"
BASE_DIR = Path(__file__).parent.resolve()


# ─── helpers ──────────────────────────────────────────────────────────────────

def _server_exe() -> Path:
    """Chemin vers l'exécutable backend compilé (sortie Nuitka, voir
    server_main.py)."""
    if platform.system() == "Windows":
        return BASE_DIR / "server" / "sabotaypro-server.exe"
    return BASE_DIR / "server" / "sabotaypro-server"


# ══════════════════════════════════════════════════════════════════════════════
# Windows Service (pywin32 / sc.exe)
# ══════════════════════════════════════════════════════════════════════════════

def _windows_install():
    exe = _server_exe()
    cmd = [
        "sc", "create", SERVICE_NAME,
        f"binPath= \"{exe}\"",
        "start=", "auto",
        "DisplayName=", SERVICE_DISPLAY,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"❌  {result.stderr.strip()}")
    else:
        subprocess.run(
            ["sc", "description", SERVICE_NAME, SERVICE_DESC], capture_output=True
        )
        print(f"✅  Service '{SERVICE_NAME}' installé.")


def _windows_start():
    r = subprocess.run(["sc", "start", SERVICE_NAME], capture_output=True, text=True)
    print("✅  Démarré." if r.returncode == 0 else f"❌  {r.stderr.strip()}")


def _windows_stop():
    r = subprocess.run(["sc", "stop", SERVICE_NAME], capture_output=True, text=True)
    print("✅  Arrêté." if r.returncode == 0 else f"❌  {r.stderr.strip()}")


def _windows_remove():
    _windows_stop()
    r = subprocess.run(["sc", "delete", SERVICE_NAME], capture_output=True, text=True)
    print("✅  Supprimé." if r.returncode == 0 else f"❌  {r.stderr.strip()}")


def _windows_status():
    r = subprocess.run(["sc", "query", SERVICE_NAME], capture_output=True, text=True)
    print(r.stdout)


# ══════════════════════════════════════════════════════════════════════════════
# macOS — launchd
# ══════════════════════════════════════════════════════════════════════════════

MACOS_LABEL = "com.sabotaypro.server"
MACOS_PLIST_PATH = Path(f"/Library/LaunchDaemons/{MACOS_LABEL}.plist")

MACOS_PLIST_TEMPLATE = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>{label}</string>
    <key>ProgramArguments</key>
    <array>
        <string>{exe}</string>
    </array>
    <key>WorkingDirectory</key>
    <string>{workdir}</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/var/log/sabotaypro/server.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/sabotaypro/server_error.log</string>
</dict>
</plist>
"""


def _macos_install():
    exe = _server_exe()
    plist = MACOS_PLIST_TEMPLATE.format(label=MACOS_LABEL, exe=exe, workdir=BASE_DIR)
    Path("/var/log/sabotaypro").mkdir(parents=True, exist_ok=True)
    MACOS_PLIST_PATH.write_text(plist)
    subprocess.run(["launchctl", "load", "-w", str(MACOS_PLIST_PATH)])
    print(f"✅  Service launchd installé : {MACOS_PLIST_PATH}")


def _macos_start():
    subprocess.run(["launchctl", "start", MACOS_LABEL])
    print("✅  Démarré.")


def _macos_stop():
    subprocess.run(["launchctl", "stop", MACOS_LABEL])
    print("✅  Arrêté.")


def _macos_remove():
    subprocess.run(["launchctl", "unload", "-w", str(MACOS_PLIST_PATH)])
    if MACOS_PLIST_PATH.exists():
        MACOS_PLIST_PATH.unlink()
    print("✅  Service supprimé.")


# ══════════════════════════════════════════════════════════════════════════════
# Dispatcher
# ══════════════════════════════════════════════════════════════════════════════

def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} install|start|stop|remove|status")
        sys.exit(1)

    action = sys.argv[1].lower()
    os_name = platform.system()

    ops = {
        "Windows": {
            "install": _windows_install,
            "start":   _windows_start,
            "stop":    _windows_stop,
            "remove":  _windows_remove,
            "status":  _windows_status,
        },
        "Darwin": {
            "install": _macos_install,
            "start":   _macos_start,
            "stop":    _macos_stop,
            "remove":  _macos_remove,
            "status":  lambda: subprocess.run(["launchctl", "list", MACOS_LABEL]),
        },
    }

    if os_name not in ops:
        print(f"❌  OS non supporté : {os_name} (Sabotay ne cible que Windows/macOS)")
        sys.exit(1)

    fn = ops[os_name].get(action)
    if not fn:
        print(f"❌  Action inconnue : {action}")
        sys.exit(1)

    fn()


if __name__ == "__main__":
    main()
