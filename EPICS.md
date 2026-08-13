# SabotayPro — Epics

Suivi de l'initiative "architecture pos_api" (paiement hors-ligne, sync cloud⇄local, bureau packagé). Document de suivi, pas une spec produit — le PRD (`PRD_SabotayPro_SaaS.md`) reste la référence fonctionnelle. Mis à jour au fil des sessions ; chaque epic liste ce qui reste explicitement pour qu'une future session (ou un autre humain) n'ait pas à reconstituer le contexte depuis l'historique de conversation.

---

## Epic 1 — Paiement & licence hors-ligne ✅ Terminé

**Objectif** : historique des paiements d'abonnement, licence Ed25519 vérifiable sans réseau, file d'attente offline pour la collecte mobile.

- Backend : table `paiements_abonnement` (migration `0016`), `GET /abonnement/paiements`, `GET /abonnement/licence` (blob signé Ed25519, `backend/app/core/licence.py`).
- Web + Mobile : `core/licence/licence_verifier.dart` (dupliqué intentionnellement dans les deux apps), bannière non bloquante sur abonnement expirant/expiré.
- Mobile : `core/network/offline_queue_service.dart` + `offline_drain_controller.dart` — la collecte (`POST /transactions`) survit à une coupure réseau au moment de l'envoi, rejouée automatiquement.

**Limites connues, pas des bugs** :
- La clé Ed25519 en place est celle générée en dev cette session (`backend/scripts/generate_licence_keypair.py`) — **à régénérer pour staging/prod** et à reporter dans les deux `licence_verifier.dart`.
- La file offline mobile n'aide que le cas "compte déjà chargé, réseau perdu juste avant l'envoi" — pas une vraie journée hors-ligne (pas de cache local des clients/comptes). Voir Epic 6.
- Le retrait (`POST /transactions/retrait`) est volontairement exclu de la file (dépend d'un solde non vérifiable hors-ligne).

---

## Epic 2 — Moteur de sync cloud ⇄ local (Phase 2a) ✅ Terminé

**Objectif** : le backend peut tourner en mode mono-tenant sur SQLite (`LOCAL_MODE=true`) et se synchroniser avec le cloud multi-tenant Postgres.

- `backend/app/api/v1/endpoints/sync.py` : `/sync/token`, `/sync/push`, `/sync/pull`, `/sync/run`, `/sync/status`.
- `backend/app/services/local_sync_client.py` : cycle push-puis-pull par entité, watermarks (`sync_state`).
- Mode local : schéma dérivé de `SQLModel.metadata.create_all()` (pas d'Alembic côté local), proxy en lecture seule des routes `/abonnement/*` vers le cloud (jamais de clé privée de licence sur un poste local).
- Dates métier rendues **naïves, en heure locale Haïti** (America/Port-au-Prince — pas UTC) pour éviter les incompatibilités SQLite/Postgres, même convention que pos_api (`now_local()`), appliquée à la création ET à la modification de tous les champs concernés (pas seulement `updated_at`) — `backend/app/core/dt_utils.py`, migrations `0018` (updated_at → naïf, une première fois en UTC) puis `0020` (tous les champs DateTime métier + décalage `updated_at` UTC→Haïti). Le blob de licence (`core/licence.py`) réattache explicitement le fuseau Haïti à `essai_fin` avant sérialisation JSON — sinon un client Dart interprète une chaîne ISO sans offset comme heure locale de l'appareil, pas Haïti.

**Testé** : pull initial, création hors-ligne, push, aller-retour cloud confirmé (voir Epic 3 pour la suite — id négatifs remplacés par UUID).

**Vérification de compatibilité post-UUID (nouvelle session)** : deuxième instance backend réelle démarrée en local (`LOCAL_MODE=true`, SQLite, port 8002) à côté du cloud (Postgres, port 8001), cycle de sync complet exécuté dans les deux sens (pull initial de 6 clients/1 compte/1 transaction, création d'un client "hors-ligne" via l'API du poste local, push vers le cloud, vérifié par `SELECT` direct sur Postgres). A confirmé au passage que **la boucle de sync périodique automatique (`_boucle_sync_periodique`, 60s) fonctionne correctement en conditions réelles à deux process** — jusque-là jamais testée (voir item "Ouvert" ci-dessous, maintenant partiellement levé) : elle a poussé le nouveau client d'elle-même avant même l'appel manuel de vérification.

**Bug réel trouvé et corrigé pendant cette vérification** : `backend/app/services/local_sync_client.py::_local_entreprise_id()` faisait encore `int(claims["entreprise_id"])` sur le claim JWT — cassait immédiatement (`ValueError`) tout cycle de sync local dès que `entreprise_id` est devenu un UUID string (Epic 3, round 2). Retypé en `str(...)`.

**Ouvert** :
- Gestion de conflit toujours limitée à "dernier `updated_at` gagne" — acceptable pour un seul poste local par entreprise, à revisiter si plusieurs postes locaux pour la même entreprise deviennent un cas réel.

---

## Epic 3 — Migration des id vers UUID ✅ Terminé

**Objectif** : remplacer tous les id auto-incrémentés par des UUID générés à la construction de l'objet — même pattern que `UUIDBase` de pos_api. Élimine le mécanisme d'id négatifs/remap de l'Epic 2 (déjà supprimé) et évite toute distinction "cette table est UUID, celle-là reste int" à retenir plus tard.

- **Round 1** (migration `0019`) : `utilisateurs`, `clients`, `comptes_sabotay`, `transactions`.
- **Round 2** (migration `0021`, décision explicitement révisée pour couvrir *tous* les id sans exception) : `entreprises` (y compris son propre id, initialement laissé en `int` puis reconsidéré) et tout ce qui en dépendait — `abonnements`, `paiements_abonnement`, `password_reset_tokens`, `super_admins`, `platform_config`, `sync_state`, plus les colonnes `entreprise_id`/`abonnement_id` de toutes les tables qui les référencent.
- Colonnes shadow, backfill parents→enfants, bascule PK/FK/UNIQUE — même approche pour les deux migrations, données existantes préservées (vérifié par requêtes croisées id/FK avant/après, et par un cycle de sync bout-en-bout après coup).
- **Bug trouvé pendant l'écriture de `0021` et corrigé rétroactivement dans les deux migrations** : un `DROP COLUMN` sur l'ancienne colonne `int` fait perdre silencieusement, côté Postgres, tout index simple (non-unique) qui lui était attaché — renommer la colonne shadow à sa place ne restaure pas cet index (il n'a jamais existé dessus). `0019` et `0021` recréent maintenant ces index explicitement ; la base de dev a été rattrapée à la main pour correspondre à ce que produirait un `alembic upgrade head` propre depuis zéro.
- `backend/app/core/local_ids.py` supprimé — plus nécessaire.
- Web + Mobile : tous les domain models/repositories/providers/écrans/routeur retypés `int` → `String` (~60 fichiers au total sur les 3 codebases, superadmin inclus). `flutter analyze` 0 erreur, `flutter test` passe (web + mobile), `flutter build web` passe.
- **Bug trouvé au passage** : `superAdminSelfIdProvider` (web) décodait le claim JWT `sub` en supposant un entier (`int.tryParse`) — cassé silencieusement dès que `sub` est devenu un UUID string. Corrigé.

**Effet cosmétique noté, pas corrigé** : `Transaction.id` affiché tel quel sur les reçus/rapports (`TR-${transaction.id}`) devient un UUID long au lieu d'un numéro court. `CompteSabotay.numeroCompte` (ex. `SB-000001`) n'est pas concerné. Si ça gêne à l'usage → epic séparé "numéro de transaction séquentiel affichable", ne pas le confondre avec l'id technique.

---

## Epic 4 — Design, responsivité, couleurs 🟡 Partiel

**Fait** : `fillColor` des champs de saisie changé de `colorScheme.surface` à `colorScheme.surfaceVariant` (web + mobile, `core/theme/app_theme.dart`) — un champ rempli de la même couleur que la Card/le BottomSheet qui le contient s'y fondait visuellement.

**Reste à faire** : la demande initiale ("revoir un peu le design, la responsivité") était large et sans captures d'écran — un audit code-only (sans navigateur/émulateur pour rendre visuellement) ne peut aller plus loin que des vérifications structurelles (breakpoints déjà présents dans plusieurs écrans web via `LayoutBuilder`, pas de `DataTable` non scrollable trouvé). **Pour aller plus loin, il faut soit des captures d'écran de pages précises à problème, soit une session avec accès navigateur réel.**

---

## Epic 5 — Serveur local desktop packagé (Phase 2b) 🟡 En cours

**Objectif** : ce que l'Epic 2 a rendu possible en théorie (mode local) devient une vraie installation chez un client — exécutable compilé, service OS, installateur signé, CI. Réplique le pipeline pos_api (`pos_api/.github/workflows/build.yml`, `pos_api/service_wrapper.py`, `pos_api/certificat/*.iss`), publié en miroir public sur **`infini-software/sabotay`** (confirmé par l'utilisateur, même mécanisme que `infini-software/pos`).

Décisions prises : **Nuitka** (comme pos_api) ; cible desktop Flutter **Windows + macOS** dès ce premier jet (macOS sans signature/notarization, comme pos_api) ; **un seul installeur** par machine (contrairement à pos_api qui a `pos-server.iss`/`pos-client.iss` séparés pour une topologie multi-postes LAN) — backend + UI bundlés ensemble, cohérent avec le modèle "un poste local par entreprise" (Epic 2).

### 5a. Point d'entrée compilable ✅ Terminé
- `backend/server_main.py` créé, calqué sur `pos_api/server_main.py` : imports forcés des packages chargés dynamiquement (`psycopg`, `aiosqlite`, `passlib.handlers.bcrypt`, `jose`, `cryptography`, `multipart`, `aiosmtplib`, `twilio`, `dotenv`, `alembic`), `_fix_workdir()`, log de crash (`%PROGRAMDATA%/SabotayPro` / `~/Library/Application Support/SabotayPro`), popup d'erreur Windows.
- `SERVER_HOST`/`SERVER_PORT` ajoutés à `Settings`.
- `tzdata` (paquet pip, pas la tzdata système) ajouté à `requirements.txt` — sans lui, `zoneinfo.ZoneInfo("America/Port-au-Prince")` (`dt_utils.now_local()`) plante sur un binaire compilé Windows (pas de tzdata OS, contrairement à macOS/Linux) ; Nuitka lui-même refuse de compiler sans ce paquet installé (`--include-package=tzdata` échoue si absent de l'environnement).
- Testé en mode source (`python server_main.py`, `GET /health` → 200) **et compilé réellement avec Nuitka en standalone sur macOS** (`python -m nuitka --standalone --include-package=app ... server_main.py`) — confirme qu'aucun import dynamique n'a été oublié avant d'écrire le CI.

### 5b. Service OS ✅ Terminé
- `backend/service_wrapper.py` créé, calqué sur celui de pos_api — Windows (`sc.exe create/start/stop/delete/query`) et macOS (`launchd`, plist dans `/Library/LaunchDaemons/com.sabotaypro.server.plist`). Pas de branche Linux (hors scope). CLI `install|start|stop|remove|status`.
- L'installeur Windows (5d) n'appelle **pas** ce script au runtime (évite une dépendance Python sur le poste final) — il inline directement les mêmes commandes `sc.exe` dans son `[Run]`/`[UninstallRun]`. `service_wrapper.py` reste utile pour les tests manuels/macOS.

### 5c. Cible desktop Flutter ✅ Terminé
- `flutter create --platforms=windows,macos .` exécuté dans `web/`.
- **Bug de sandbox macOS trouvé et corrigé** : les entitlements générés par défaut (`DebugProfile.entitlements`, `Release.entitlements`) ne déclarent que `com.apple.security.network.server`, jamais `com.apple.security.network.client` — sans ce dernier, l'App Sandbox macOS bloque silencieusement toute requête HTTP sortante (donc tout appel à l'API locale). Ajouté aux deux fichiers.
- Nom de produit/bundle : `PRODUCT_NAME`/`ProductName` etc. passés de `sabotaypro`/`com.example.sabotaypro` à `SabotayPro`/`com.sabotaypro.desktop` (`macos/Runner/Configs/AppInfo.xcconfig`, `windows/runner/Runner.rc`) — **`com.sabotaypro.desktop` est un identifiant provisoire**, à confirmer avant toute notarization/soumission store réelle.
- **`flutter build macos --debug` exécuté réellement** (le seul des deux buildable localement, macOS) → `SabotayPro.app` généré avec succès. `flutter build windows` non testable ici (nécessite un runner Windows, testé pour la première fois en CI, 5e).
- `Env.apiBaseUrl` (`web/lib/core/network/env.dart`) pointe déjà par défaut sur `http://127.0.0.1:8001/api/v1` — correspond exactement au port par défaut du service local bundlé, aucun changement nécessaire.

### 5d. Installateur Windows signé ✅ Terminé (non compile-testé — nécessite Windows)
- `certificat/sabotaypro-desktop.iss` créé — un seul installeur (voir décision ci-dessus), bundle `backend-windows\*` (sortie Nuitka) dans `{app}\server\`, `frontend-windows\*` (build Flutter) dans `{app}\`, enregistre le service via `sc.exe create` inline dans `[Run]`, génère un `.env` minimal (`LOCAL_MODE=true`, SQLite, `SECRET_KEY` aléatoire par installation, sans `CLOUD_SYNC_URL`/`TOKEN` — voir 5f) via du code Pascal (`CurStepChanged`/`SaveStringsToFile`/`GetSHA1OfString`, fonctions standard Inno Setup).
- **Certificat de signature Authenticode : réutilise celui de pos_api**, confirmé par l'utilisateur. Le certificat **public** (`.cer`, sûr à distribuer — c'est tout l'intérêt d'Authenticode) a été copié tel quel depuis `pos_api/certificat/setup-info/posconnect-codesign.cer` vers `certificat/setup-info/sabotaypro-codesign.cer`. Le `.pfx` privé, lui, n'a pas été touché (jamais dans le repo, ni chez pos_api ni ici).
- **Action manuelle requise côté utilisateur, inchangée** : ajouter les secrets `WIN_CODESIGN_PFX_BASE64`/`WIN_CODESIGN_PFX_PASSWORD` (mêmes valeurs que pos_api) **et** un nouveau `INFINI_SOFTWARE_RELEASE_TOKEN` (PAT avec accès en écriture sur `infini-software/sabotay`, probablement différent de celui de pos_api si c'est un dépôt distinct) au repo GitHub de Sabotay.
- **Non vérifié** : script Inno Setup jamais compilé (`ISCC.exe` n'existe pas sur macOS) — écrit avec soin en suivant la syntaxe standard Inno Setup (fonctions Pascal `GetSHA1OfString`/`SaveStringsToFile` confirmées documentées), mais la première vraie validation aura lieu au premier run du CI (5e) sur `windows-latest`.

### 5e. GitHub Actions CI ✅ Écrit — **rien n'est encore commité ni poussé sur GitHub**
- `.github/workflows/build.yml` créé à la racine de Sabotay, calqué sur celui de pos_api : `determine-version` → `backend-windows`/`backend-macos` (Nuitka) → `frontend-windows`/`frontend-macos` (Flutter) → `inno-setup` (Windows, signé) → `release` (assemble + publie sur le repo Sabotay + miroir `infini-software/sabotay`, `continue-on-error` si le token n'est pas encore configuré).
- Pas de job Linux, pas de packaging web dans ce pipeline (le déploiement web suit un chemin séparé, non couvert ici).
- **Important, source de confusion pendant la session** : ce dépôt n'a **aucun remote GitHub configuré** (`git remote -v` vide) et un seul commit existe au total (le commit initial, avant toute cette initiative). Tous les fichiers de cette session — y compris `.github/workflows/build.yml` — sont non trackés (`git status` les montre en `??`), donc invisibles sur GitHub *par construction*, pas à cause d'un bug d'écriture du workflow. Rien ne sera visible dans l'onglet Actions d'un dépôt tant qu'il n'y a pas eu (1) un commit et (2) un remote + push vers GitHub — ni l'un ni l'autre n'a été fait cette session (aucune de ces deux actions n'a été demandée explicitement, et ce sont des actions à confirmer avant de les exécuter).
- Jamais exécuté en CI — nécessite le commit/push ci-dessus, puis un premier push de tag (`git tag v0.1.0 && git push origin v0.1.0`) ou un déclenchement manuel, une fois les secrets configurés.

### 5f. Liaison au cloud au premier lancement ✅ Terminé
En étudiant `pos_api/routes/setup.py`, la liaison poste-local↔cloud se fait via un **assistant séparé, après** que le service tourne déjà — pas dans l'installeur lui-même (`pos_server.ini` est complété à ce moment-là, pas à l'installation). Implémenté pour Sabotay selon le même principe :

- Backend : `PATCH app/core/config.py` — `update_env_file()` (persiste des clés dans `.env` sur disque, verrouillage `icacls` sous Windows car le fichier contiendra un jeton de sync longue durée — même précaution que `write_ini_config()` de pos_api pour `pos_server.ini`).
- `GET /setup/statut` et `POST /setup/connecter` (`app/api/v1/endpoints/setup.py`, `LOCAL_MODE` uniquement, 400 sinon — même garde que `/sync/run`). `POST /setup/connecter` échange le code contre un jeton via `POST /sync/redeem-code` sur le cloud, persiste `CLOUD_SYNC_URL`/`CLOUD_SYNC_TOKEN`, déclenche un `run_sync_cycle()` immédiat (pas d'attente de la boucle des 60s).
- **`installation_terminee` est dérivé des données réellement présentes** (au moins un utilisateur synchronisé), pas d'un simple flag — même principe que `_is_setup_done()` de pos_api (`db.query(User).count() > 0`) : survit à un `.env` qui contiendrait un jeton périmé sans qu'aucune donnée n'ait jamais été tirée avec succès.
- Web : nouvelle feature `web/lib/features/setup_bureau/` — écran `SetupBureauScreen` (code + URL cloud), `setupStatutProvider` (court-circuite sur `kIsWeb` : ne fait strictement aucun appel réseau sur le web navigateur, où `LOCAL_MODE` est toujours false côté serveur). Câblé dans `app_router.dart` : tant que `installationTerminee == false`, toutes les routes redirigent vers l'assistant — y compris avant le login normal.
- **Testé de bout en bout, deux fois** : (1) via curl (deux instances réelles, cloud Postgres + local SQLite vierge) — `GET /setup/statut` → `false`, génération d'un code sur le cloud, `POST /setup/connecter` → pull immédiat de 7 clients/1 compte/1 transaction, `GET /setup/statut` → `true` avec le nom de l'entreprise, retenter le même flux → `409`. (2) via l'app macOS **réellement compilée et lancée** (`open SabotayPro.app`) contre un backend local vierge : logs serveur confirmant `GET /api/v1/setup/statut` appelé par l'app au démarrage — preuve que le chemin `kIsWeb=false` s'exécute correctement de bout en bout. **Non vérifié visuellement** (screenshot impossible dans cet environnement — l'app est confirmée au premier plan par le menu bar mais aucune fenêtre ne s'affiche à la capture, limite de l'environnement d'exécution, pas du code).
- **Bug réel trouvé et corrigé pendant ce test** : mon propre harnais de test a écrit `CLOUD_SYNC_URL`/`CLOUD_SYNC_TOKEN` de test dans le **vrai** `backend/.env` de dev (au lieu du `.env` d'une instance jetable) — `update_env_file()` résout `.env` relatif au `cwd` du process, exactement comme `pydantic-settings`, ce qui est correct en production (`_fix_workdir()` garantit que le cwd est le dossier de l'exe) mais suppose que qui lance le process se place dans le bon dossier. Nettoyé (valeurs vidées) ; `LICENCE_PRIVATE_KEY` et le reste du fichier n'ont pas été affectés.

---

## Epic 7 — Code d'installation bureau 🟡 Backend + consommation terminés, génération sans UI

**Objectif** : permettre de lier un poste local au cloud avec un simple code à saisir (`ABCD-EFGH-IJKL`) plutôt que de taper email/mot de passe sur la machine du client — même pattern que pos_api (`InstallationCode`), demandé explicitement par l'utilisateur.

- `backend/app/models/code_installation.py` (table `codes_installation`, migration `0022`) — simplifié par rapport à pos_api : pas de notion de dépôt/warehouse (un seul poste local par entreprise, Epic 2), donc pas d'étape de "claim" séparée. Un code appartient directement à une `entreprise_id` et se marque `utilise=True` dès son échange contre un jeton de sync.
- `GET/POST /entreprises/code-installation` (Admin uniquement) : `GET` renvoie le code non-utilisé courant (généré à la demande s'il n'existe pas) ; `POST` invalide le(s) code(s) non utilisés existants et en génère un nouveau.
- `POST /sync/redeem-code` (public, pas d'auth) : échange un code contre un jeton de sync (365 jours, identique à `POST /sync/token`), 404 si code invalide, 409 si déjà utilisé.
- **Consommation côté poste local terminée** — voir Epic 5f (`SetupBureauScreen`, `POST /setup/connecter`).
- **Testé de bout en bout via curl** : génération idempotente, échange réussi → jeton valide pour `/sync/pull`, réutilisation → 409, régénération → ancien code (non utilisé) supprimé, historique des codes utilisés conservé en base.
- **Reste à faire** : aucune UI web pour la *génération* — `Admin → Entreprise` n'affiche pas encore ce code (l'écran qui le *consomme*, côté poste local, existe désormais ; celui qui le *montre*, côté cloud, non).

---

## Epic 6 — Offline-first mobile complet ⬜ Pas commencé, pas confirmé prioritaire

Explicitement hors-scope du MVP par le PRD (§5.2 : "Mode hors-ligne (offline-first) pour les agents" listé comme hors scope, prévu Phase 2 du PRD lui-même). L'Epic 1 a livré une résilience partielle (file d'attente pour la collecte en cours). Un offline-first complet (cache local des clients/comptes, agent travaillant une journée entière sans réseau) demanderait le même genre de moteur de sync que l'Epic 2, mais côté mobile (SQLite local + entités mises en cache en lecture) — **à ne pas entamer sans confirmation explicite que c'est maintenant prioritaire**, PRD à jour dit le contraire.
