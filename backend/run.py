"""Point d'entrée dev pour Windows.

psycopg (mode async) est incompatible avec le ProactorEventLoop par défaut
d'asyncio sur Windows — il faut forcer le SelectorEventLoop *avant* qu'uvicorn
ne crée sa boucle d'événements. `uvicorn app.main:app` en CLI ne permet pas
cette étape, d'où ce script séparé au lieu de la commande directe.
"""

import asyncio
import os
import sys

if sys.platform == "win32":
    asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())

import uvicorn

if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8001"))
    uvicorn.run("app.main:app", host="127.0.0.1", port=port, reload=True)
