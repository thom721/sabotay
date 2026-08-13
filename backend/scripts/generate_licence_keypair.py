"""Génère une paire de clés Ed25519 pour la signature du blob de licence.

Usage : `python scripts/generate_licence_keypair.py` (depuis backend/, dans
le venv). N'écrit aucun fichier — affiche les deux clés en base64 à copier
manuellement : la clé privée dans `.env` (LICENCE_PRIVATE_KEY, jamais
commitée), la clé publique dans les deux clients Flutter
(lib/core/licence/licence_verifier.dart, web/ et mobile/).

À exécuter une seule fois par environnement (dev/staging/prod) — régénérer
invalide toutes les licences déjà mises en cache côté client.
"""

import base64

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives.serialization import (
    Encoding,
    NoEncryption,
    PrivateFormat,
    PublicFormat,
)

private_key = Ed25519PrivateKey.generate()
public_key = private_key.public_key()

private_bytes = private_key.private_bytes(
    encoding=Encoding.Raw, format=PrivateFormat.Raw, encryption_algorithm=NoEncryption()
)
public_bytes = public_key.public_bytes(encoding=Encoding.Raw, format=PublicFormat.Raw)

print("LICENCE_PRIVATE_KEY (backend .env — secret, jamais commité) :")
print(base64.b64encode(private_bytes).decode("ascii"))
print()
print("Clé publique (à coller dans licence_verifier.dart, web/ et mobile/) :")
print(base64.b64encode(public_bytes).decode("ascii"))
