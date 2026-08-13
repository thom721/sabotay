# Image du backend FastAPI.
#
# Contexte de build = ce dossier (backend/) lui-même — voir
# deploiement/docker-compose.yml, build.context: ../backend.
#
# Pas de dépendances système à compiler (gcc, headers) : psycopg[binary]
# (Postgres) et cryptography embarquent des roues précompilées manylinux —
# contrairement à MySQL (mysqlclient/PyMySQL), aucun besoin de
# gcc/libmysqlclient-dev/pkg-config ici.
FROM python:3.11-slim

WORKDIR /app

# Dépendances d'abord, séparément du code — le cache Docker ne réinstalle
# les paquets que si requirements.txt change, pas à chaque modification de
# code applicatif. gunicorn est déjà dans requirements.txt (pas d'install
# ad-hoc séparée, pour rester reproductible/pinné comme le reste).
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN mkdir -p /app/logs

EXPOSE 9004

# Migre le schéma avant de démarrer — un seul conteneur (pas de scaling
# horizontal ici), donc pas de risque de migrations concurrentes.
#
# gunicorn + workers uvicorn : gestion de process de qualité production
# (respawn automatique d'un worker qui plante, meilleure utilisation
# multi-cœur qu'un uvicorn seul) — un seul process asyncio ne peut utiliser
# qu'un cœur CPU à la fois. Logs vers /app/logs (voir docker-compose.yml,
# volume ./logs:/app/logs).
#
# `sh -c ... && exec` : exec remplace le shell par gunicorn (PID 1), pour
# que SIGTERM (docker stop) l'atteigne directement au lieu d'être avalé par
# un sous-shell.
CMD ["sh", "-c", "alembic upgrade head && exec gunicorn app.main:app \
     --workers 4 \
     --worker-class uvicorn.workers.UvicornWorker \
     --bind 0.0.0.0:9004 \
     --timeout 120 \
     --access-logfile /app/logs/access.log \
     --error-logfile /app/logs/error.log"]
