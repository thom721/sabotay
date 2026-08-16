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

**Effet cosmétique noté, pas corrigé** : `Transaction.id` affiché tel quel sur les reçus/rapports (`TR-${transaction.id}`) devient un UUID long au lieu d'un numéro court. `CompteSabotay.numeroCompte` (ex. `SB-000001`) n'est pas concerné. Si ça gêne à l'usage → epic séparé "numéro de transaction séquentiel affichable", ne pas le confondre avec l'id technique. **Corrigé — voir Epic 18.**

---

## Epic 4 — Design, responsivité, couleurs 🟡 Partiel

**Fait** :
- `fillColor` des champs de saisie changé de `colorScheme.surface` à `colorScheme.surfaceVariant` (web + mobile, `core/theme/app_theme.dart`) — un champ rempli de la même couleur que la Card/le BottomSheet qui le contient s'y fondait visuellement.
- **Bug réel trouvé via une vraie capture d'écran de l'app bureau (login)** : `ElevatedButtonThemeData` ne fixait ni `backgroundColor` ni `foregroundColor` — en Material 3 (`useMaterial3: true`), `ElevatedButton` est par défaut un bouton "tonal" discret (fond `surface` teinté, texte `primary`), pas un bouton plein comme en Material 2. Résultat : **tout bouton d'action principale de toute l'app** (web et mobile — "Se connecter" en particulier, mais tous les autres `ElevatedButton` du code sans exception) ressemblait à un simple lien texte, à peine distinguable des vrais liens secondaires (`TextButton`) à côté. Corrigé dans les deux `app_theme.dart` (`backgroundColor: colorScheme.primary`, `foregroundColor: colorScheme.onPrimary` — reproduit le comportement d'un `FilledButton` M3 sans migrer tous les call sites).

**Reste à faire** : la demande initiale ("revoir un peu le design, la responsivité") était large — la première vraie capture d'écran obtenue cette session (app bureau macOS) a permis de trouver ce bug de bouton, mais une seule page a été vue. Les autres écrans (formulaires en Card, tableaux, portail Client) n'ont toujours pas été audités visuellement. **Pour aller plus loin, il faut soit d'autres captures d'écran de pages précises, soit une session avec accès navigateur/app réel.**

---

## Epic 5 — Serveur local desktop packagé (Phase 2b) 🟡 En cours

**Objectif** : ce que l'Epic 2 a rendu possible en théorie (mode local) devient une vraie installation chez un client — exécutable compilé, service OS, installateur signé, CI. Réplique le pipeline pos_api (`pos_api/.github/workflows/build.yml`, `pos_api/service_wrapper.py`, `pos_api/certificat/*.iss`), publié en miroir public sur **`infini-software/sabotay`** (confirmé par l'utilisateur, même mécanisme que `infini-software/pos`).

Décisions prises : **Nuitka** (comme pos_api) ; cible desktop Flutter **Windows + macOS** dès ce premier jet (macOS sans signature/notarization, comme pos_api) ; **un seul installeur** par machine (contrairement à pos_api qui a `pos-server.iss`/`pos-client.iss` séparés pour une topologie multi-postes LAN) — backend + UI bundlés ensemble, cohérent avec le modèle "un poste local par entreprise" (Epic 2).

### 5a. Point d'entrée compilable ✅ Terminé
- `backend/server_main.py` créé, calqué sur `pos_api/server_main.py` : imports forcés des packages chargés dynamiquement (`psycopg`, `aiosqlite`, `passlib.handlers.bcrypt`, `jose`, `cryptography`, `multipart`, `aiosmtplib`, `twilio`, `dotenv`, `alembic`), `_fix_workdir()`, log de crash (`%PROGRAMDATA%/SabotayPro` / `~/Library/Application Support/SabotayPro`), popup d'erreur Windows.
- `SERVER_HOST`/`SERVER_PORT` ajoutés à `Settings` — `SERVER_PORT` par défaut **9004** (pas 9003, celui de pos_api — distinct exprès pour ne jamais entrer en conflit si les deux produits sont installés sur le même poste ; confirmé par l'utilisateur, initialement 8001 par erreur, corrigé partout : `Env.apiBaseUrl` web, `.env` généré par `certificat/sabotaypro-desktop.iss`).
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
- `Env.apiBaseUrl` (`web/lib/core/config/env.dart`) pointe par défaut sur `http://127.0.0.1:9004/api/v1` — correspond exactement au port par défaut du service local bundlé.

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
- Web : nouvelle feature `web/lib/features/setup_bureau/` — écran `SetupBureauScreen` (code d'installation uniquement ; l'URL du cloud n'est **pas** un champ éditable — figée côté client via `Env.defaultCloudUrl`, affichée en lecture seule/grisée, sur demande explicite de l'utilisateur pour qu'un client ne puisse jamais la modifier), `setupStatutProvider` (court-circuite sur `Env.isDesktopBureau` : ne fait strictement aucun appel réseau sur le web navigateur, où `LOCAL_MODE` est toujours false côté serveur). Câblé dans `app_router.dart` : tant que `installationTerminee == false`, toutes les routes redirigent vers l'assistant — y compris avant le login normal.
- `Env.defaultCloudUrl` : `https://sabotay.infini-software.cloud` — **domaine de production confirmé par l'utilisateur** (même lien pour le web et la synchronisation), injecté à la compilation via `--dart-define=CLOUD_URL=...` par le CI (`.github/workflows/build.yml`, input `cloud_url`) mais codé en dur comme repli même sans ce flag — pas besoin de le repasser à chaque build (même principe que pos_api). Remplace l'ancien placeholder `https://sabotaypro.com`, présent aussi dans `certificat/sabotaypro-desktop.iss` (`MyAppURL`), corrigé au même endroit.
- **Testé de bout en bout, deux fois** : (1) via curl (deux instances réelles, cloud Postgres + local SQLite vierge) — `GET /setup/statut` → `false`, génération d'un code sur le cloud, `POST /setup/connecter` → pull immédiat de 7 clients/1 compte/1 transaction, `GET /setup/statut` → `true` avec le nom de l'entreprise, retenter le même flux → `409`. (2) via l'app macOS **réellement compilée et lancée** (`open SabotayPro.app`) contre un backend local vierge : logs serveur confirmant `GET /api/v1/setup/statut` appelé par l'app au démarrage — preuve que le chemin `kIsWeb=false` s'exécute correctement de bout en bout. **Non vérifié visuellement** (screenshot impossible dans cet environnement — l'app est confirmée au premier plan par le menu bar mais aucune fenêtre ne s'affiche à la capture, limite de l'environnement d'exécution, pas du code).
- **Bug réel trouvé et corrigé pendant ce test** : mon propre harnais de test a écrit `CLOUD_SYNC_URL`/`CLOUD_SYNC_TOKEN` de test dans le **vrai** `backend/.env` de dev (au lieu du `.env` d'une instance jetable) — `update_env_file()` résout `.env` relatif au `cwd` du process, exactement comme `pydantic-settings`, ce qui est correct en production (`_fix_workdir()` garantit que le cwd est le dossier de l'exe) mais suppose que qui lance le process se place dans le bon dossier. Nettoyé (valeurs vidées) ; `LICENCE_PRIVATE_KEY` et le reste du fichier n'ont pas été affectés.

---

## Epic 7 — Code d'installation bureau ✅ Terminé

**Objectif** : permettre de lier un poste local au cloud avec un simple code à saisir (`ABCD-EFGH-IJKL`) plutôt que de taper email/mot de passe sur la machine du client — même pattern que pos_api (`InstallationCode`), demandé explicitement par l'utilisateur.

- `backend/app/models/code_installation.py` (table `codes_installation`, migration `0022`) — simplifié par rapport à pos_api : pas de notion de dépôt/warehouse (un seul poste local par entreprise, Epic 2), donc pas d'étape de "claim" séparée. Un code appartient directement à une `entreprise_id` et se marque `utilise=True` dès son échange contre un jeton de sync.
- `GET/POST /entreprises/code-installation` (Admin uniquement) : `GET` renvoie le code non-utilisé courant (généré à la demande s'il n'existe pas) ; `POST` invalide le(s) code(s) non utilisés existants et en génère un nouveau.
- `POST /sync/redeem-code` (public, pas d'auth) : échange un code contre un jeton de sync (365 jours, identique à `POST /sync/token`), 404 si code invalide, 409 si déjà utilisé.
- **Consommation côté poste local terminée** — voir Epic 5f (`SetupBureauScreen`, `POST /setup/connecter`).
- **Testé de bout en bout via curl** : génération idempotente, échange réussi → jeton valide pour `/sync/pull`, réutilisation → 409, régénération → ancien code (non utilisé) supprimé, historique des codes utilisés conservé en base.
- **UI de génération ajoutée (session ultérieure)** : carte "Installation bureau" sur `Admin → Entreprise` (`entreprise_profile_screen.dart`, visible Admin uniquement — le backend exige déjà `require_roles(ADMIN)`) — affiche le code courant, bouton copier, bouton régénérer avec confirmation. Épic fermé : génération et consommation ont désormais toutes les deux une UI.

---

## Epic 8 — Bootstrap du premier compte super-admin (web) ✅ Terminé

**Objectif** : au tout premier déploiement cloud, aucun compte super-admin n'existe — jusqu'ici il fallait en créer un directement en base via un script Python (fait manuellement pendant cette session, faute de mieux). Demandé explicitement : un vrai flux web pour ça, comme pos_api.

- Backend (`superadmin_auth.py`, routeur `/auth`, public — aucun compte n'existe encore pour s'authentifier) :
  - `GET /auth/superadmin-bootstrap` → `{necessaire: bool}`, dérivé de `count(SuperAdmin) == 0` — même principe que `/setup/statut` (Epic 5f) et `_is_setup_done()` de pos_api.
  - `POST /auth/superadmin-bootstrap` → crée le compte, **verrouillé définitivement** dès qu'un compte existe déjà (403) — contrairement à `POST /superadmin/comptes` (toujours ouvert mais exige déjà d'être authentifié, impossible au tout premier déploiement).
- Web : `SuperAdminBootstrapScreen` (nouvelle route `/superadmin/premier-compte`) — crée le compte puis connecte automatiquement (même schéma que `AuthController.registerEntreprise` côté staff : un seul appel écran). `SuperAdminLoginScreen` redirige vers cet écran si `necessaire=true` ; l'écran de bootstrap redirige vers le login si un compte existe déjà (accès direct après coup).
- **Testé via curl** : `GET` correct avec des comptes existants (`necessaire:false`), `POST` correctement bloqué (403) tant qu'au moins un compte existe. Le chemin `necessaire:true` (base vide) n'a pas été testé en conditions réelles pour ne pas vider la base de dev existante — logique triviale (`count == 0`), risque jugé négligeable.
- **Erreur corrigée après coup — réservé au web, jamais au bureau, sur demande explicite de l'utilisateur** : `web/` est désormais compilé à la fois pour le navigateur ET pour l'app bureau (Epic 5c), et `super_admins` n'est jamais peuplé en local (donnée de plateforme, jamais synchronisée vers un poste local, voir `ENTITES` dans `sync.py`) — sans garde-fou, un poste bureau aurait toujours vu `necessaire=true` et proposé de créer un "super-admin" local fantôme. Doublement corrigé : `superAdminBootstrapNecessaireProvider` court-circuite sur `Env.isDesktopBureau` (web), et le backend renvoie `necessaire=false`/400 quand `LOCAL_MODE=true` (défense en profondeur, ne repose pas que sur l'UI — même logique que les gardes déjà en place sur `/setup/*` et `/sync/run`).
- `flutter analyze`/`test` propres, backend rechargé et revérifié après le correctif.

---

## Epic 9 — Configuration email SMTP dynamique (Paramètres → Email, super-admin) ✅ Terminé

**Objectif** : comme pos_api (`PlatformConfig.smtp_*`), permettre au super-admin de configurer le serveur SMTP d'envoi d'email **depuis l'interface**, sans redéploiement — jusqu'ici uniquement statique via `.env` (`settings.SMTP_*`).

- `PlatformConfig` (table `platform_config`, singleton) étendue : `smtp_host`, `smtp_port` (défaut 587), `smtp_user`, `smtp_password`, `smtp_from_email` — migration `0023`.
- `PATCH /superadmin/config` devient un **PATCH partiel** (`PlatformConfigUpdate` tout optionnel, `exclude_unset` côté CRUD) : l'onglet Email peut être enregistré sans toucher l'onglet Abonnement, et vice versa — testé via curl (montant changé après coup, config email intacte).
- `GET /superadmin/config` ne renvoie **jamais** le mot de passe réel — seulement `smtp_password_defini: bool` (même principe que le `"**masked**"` de pos_api, en plus strict : aucune valeur du tout, pas même masquée).
- `core/notifications.py::send_email()` lit désormais `PlatformConfig` en base (via une session ouverte à la volée, pas besoin de faire passer une session dans tous les appelants) ; les valeurs statiques `.env` (`settings.SMTP_*`) restent un **repli** si la base n'a rien de configuré (compat dev), pas une source concurrente en production.
- Web : nouvel écran `SuperAdminParametresScreen` (route `/superadmin/parametres`, tab panel — onglets "Abonnement" et "Email"), remplace l'ancien dialog "Prix abonnement" (bouton app bar renommé "Paramètres", icône `settings_outlined`). Mot de passe : champ vide = conserver l'actuel (jamais pré-rempli avec la vraie valeur, jamais renvoyé si laissé vide).
- **Testé via curl** : `GET` initial (tout vide), `PATCH` email seul, `PATCH` abonnement seul (email intact) — comportement PATCH partiel confirmé. `flutter analyze`/`test`/`build web` propres.
- **Reste à faire** : pas de bouton "Tester l'envoi" (pos_api n'en a pas non plus) ; si un jour d'autres catégories de réglages s'ajoutent (ex. paiement), ce sera un nouvel onglet dans le même écran, pas un nouvel écran séparé.

---

## Epic 10 — Suivi et réinitialisation de l'installation bureau (super-admin) ✅ Terminé

**Objectif** : le super-admin doit pouvoir voir quelles entreprises ont effectivement installé leur poste bureau, et forcer une réinstallation (ex. changement de machine) — demandé explicitement, avec une règle de bascule précise.

- `Entreprise.est_installe: bool` (migration `0024`) — **jamais réglé manuellement à `True`**, uniquement dérivé de l'activité réelle : `sync.py::_touch_sync_state()` (appelée par `push()`/`pull()` pour chacune des 5 entités synchronisées) le passe à `True` dès le premier appel réussi, quelle que soit l'entité — idempotent (no-op une fois déjà vrai). `POST /sync/redeem-code` (échange du code) ne le touche jamais : redeem-code seul = toujours `False`, confirmé par l'utilisateur (« lorsque le client tape son code d'installation … is_installe doit être false », « après la première installation et synchro … doit être true »). En pratique bascule quasi immédiatement puisque `/setup/connecter` enchaîne redeem-code + `run_sync_cycle()` dans le même appel.
- `POST /superadmin/entreprises/{id}/reinitialiser-installation` — repasse `est_installe` à `False`. Ne touche pas aux codes d'installation existants : `GET /entreprises/code-installation` régénère automatiquement un nouveau code au prochain accès (aucun code non-utilisé ne subsiste après une installation réussie — comportement déjà existant, Epic 7).
- Web : indicateur (icône ✓/○) dans la liste des entreprises et sur la fiche détail, plus un bouton "Réinitialiser l'installation" (avec confirmation, visible seulement si `est_installe=true`) sur la fiche détail.
- **Testé de bout en bout via curl** : `est_installe=false` initial sur les deux entreprises de test → cycle de sync réel (`/sync/token` + `/sync/pull`) sur l'une des deux → bascule confirmée à `true`, l'autre reste `false` → `POST .../reinitialiser-installation` → repasse à `false` → `GET /entreprises/code-installation` régénère bien un nouveau code (`utilise:false`). `flutter analyze`/`test`/`build web` propres.
- **Non couvert, noté mais pas demandé** : réinitialiser l'installation ne révoque pas le jeton de sync déjà émis à l'ancien poste (jetons stateless, pas de liste de révocation) — l'ancien poste continuerait de fonctionner tant que son jeton (365 jours) est valide. Mentionné explicitement dans le dialogue de confirmation côté web plutôt que caché.

---

## Epic 11 — Vérification d'abonnement hors-ligne (bureau) + traçabilité des paiements ✅ Terminé

**Objectif** : deux trous réels signalés par l'utilisateur.

### Vérification d'abonnement en mode local — bug bloquant corrigé
`abonnements` n'étant jamais synchronisé vers le SQLite local (voir `ENTITES`, sync.py), `_abonnement_actif()` interrogeait une table structurellement toujours vide sur un poste bureau — **la collecte (`POST /transactions`) y aurait été bloquée en permanence**, jamais testé en conditions réelles jusqu'ici (le licence Ed25519 de l'Epic 1 n'était vérifiée que côté client Dart, purement informative, jamais consultée par le serveur).

- `core/licence.py` : vérification Ed25519 côté Python (`verify_licence_blob`, même clé publique que web/mobile), `acces_autorise_depuis_payload` (réplique la décision allowed/warning/blocked du client Dart), `rafraichir_cache_local`/`abonnement_actif_local`.
- Nouvelle table `licence_cache_local` (migration `0025`, singleton comme `PlatformConfig`) — payload déjà vérifié, jamais réécrit avec un blob invalide.
- Rafraîchie par la boucle de sync périodique (`main.py`, toutes les 60s) et immédiatement par `POST /setup/connecter` — **jamais d'appel réseau au moment de la collecte elle-même** (offline-first préservé).
- `_abonnement_actif()` (transactions.py) bifurque sur `settings.LOCAL_MODE` : lit le cache local au lieu d'interroger `abonnements`.
- Dates du blob : `datetime.fromisoformat()` (stdlib), qui respecte l'offset explicite porté par `essai_fin`/`valid_until`/`issued_at` (délibérément non-naïves, contrairement au reste de la base — le blob traverse une frontière de confiance/sérialisation, voir le commentaire déjà présent dans `build_licence_payload`).
- **Testé de bout en bout** : poste local vierge → `/setup/connecter` → cache peuplé et vérifié (`abonnement_statut: actif` confirmé en base) → `POST /transactions` réussit (`201`), ce qui échouait systématiquement avant ce correctif.

### Identifiant utilisateur dans les historiques
- Retrait : déjà correct (`Transaction.collecte_par_id`/`_nom`, déjà affiché dans l'écran Rapports mobile).
- Paiement d'abonnement : `PaiementAbonnement.paye_par_id`/`paye_par_nom` ajoutés (migration `0026`), câblés dans `verifier_abonnement`/`marquer_paye_dev`, testés via curl.

### Historique de paiement + impression de reçu (web)
- Écran Abonnement (tenant, onglet déjà existant) : section "Historique des paiements" + bouton d'impression par ligne (`recu_abonnement_pdf.dart`, même format papier thermique que les reçus de collecte/retrait).
- Fiche détail entreprise (super-admin) : même section + impression, avec un `EntrepriseProfile` minimal reconstruit depuis `EntrepriseSuperAdminRead` (pas de jeton staff côté super-admin, donc pas d'accès à `GET /entreprises/profil` — seuls nom/devise garantis, le reste (adresse, texte bas de reçu) reste vide sur ce reçu-là).
- **Bugs UUID réels trouvés au passage** (oubliés lors du sweep de l'Epic 3, round 2) : `Abonnement.id` et `EntrepriseProfile.id` (web **et** mobile) étaient encore typés `int` alors que le backend renvoie un UUID depuis la migration `0021` — `GET /entreprises/profil` (appelé par tout écran de reçu) aurait planté au premier appel. Corrigés ; balayage complet (`grep "as int"`) confirmant qu'aucun autre champ d'id n'a été oublié.
- `flutter analyze`/`test`/`build web` propres (web et mobile).

---

## Epic 12 — Déploiement Docker en production ✅ Terminé

**Objectif** : passer du poste de dev à un vrai VPS de production, avec nginx déjà installé au niveau système (partagé avec d'autres sites) — demandé explicitement, avec le docker-compose réel d'un autre projet du même utilisateur (`/opt/post`) comme référence de structure à reproduire (Postgres à la place de MySQL).

- `deploiement/` à la racine : `docker-compose.yml` (services `postgres` + `backend`, réseaux `sabotay_internal` (bridge, interne) + `proxy_net` (externe, partagé au niveau VPS)), `.env` (placeholders uniquement — jamais de vraies valeurs commitées), `nginx/sabotay.conf` (fichier de site système, **pas** conteneurisé — à copier manuellement dans `/etc/nginx/sites-available/` sur l'hôte, chemins de certificats standard certbot).
- `backend/Dockerfile` : gunicorn + `uvicorn.workers.UvicornWorker` (4 workers), `alembic upgrade head` exécuté automatiquement avant le démarrage (un seul conteneur, pas de risque de migrations concurrentes), logs fichier (`/app/logs/access.log`/`error.log` — **pas** sur stdout, donc invisibles via `docker compose logs`, seulement via `docker exec ... tail /app/logs/*.log`). `backend/.dockerignore` exclut les fichiers spécifiques au binaire desktop compilé (`run.py`, `server_main.py`, `service_wrapper.py`, `scripts/`) — jamais utilisés par le conteneur.
- Le backend n'est publié que sur `127.0.0.1` (jamais `0.0.0.0`) — seul le nginx système, hors Docker, peut l'atteindre. Port choisi : **9008** (9004 initialement, changé après un conflit de port réel sur le VPS avec un process déjà en écoute — aligné en interne *et* en externe, y compris dans le `Dockerfile`/gunicorn `--bind`, pour éviter tout mapping hôte↔conteneur incohérent).
- `Settings.CORS_ORIGINS`/`cors_origins_list` — passait d'un `allow_origins=["*"]` codé en dur à une liste configurable par variable d'environnement.
- **Bug réel trouvé et corrigé** : `web/lib/core/config/env.dart::apiBaseUrl` n'avait de repli correct que pour le binaire desktop (`127.0.0.1:9004`) — en web navigateur, sans `--dart-define=API_BASE_URL` (jamais passé par la CI), l'app appelait toujours `127.0.0.1:9004` depuis le poste du **visiteur**, pas le VPS. Corrigé en deux temps : chemin relatif `/api/v1` (résolu sur le même domaine via le proxy nginx) en prod, **et** détection explicite de `localhost`/`127.0.0.1` pour retomber sur `127.0.0.1:9004` en dev local (`flutter run -d chrome`, qui n'a aucun proxy vers le backend) — sans cette deuxième branche, le dev local aurait cassé à son tour après le premier correctif.
- **Vérifié en conditions réelles sur le VPS visé** (pas seulement en local) : build Docker réel, `alembic upgrade head` rejoué proprement depuis une base vide, `curl .../health` → 200, création du premier compte super-admin via `/superadmin/premier-compte` réellement testée en production.
- **Reste à faire** : `WIN_CODESIGN_PFX_BASE64`/`WIN_CODESIGN_PFX_PASSWORD`/`INFINI_SOFTWARE_RELEASE_TOKEN` toujours pas configurés côté GitHub (voir Epic 5d/5e) — le tag `v0.2.0` poussé cette session a de nouveau échoué sur l'étape Inno Setup pour cette raison, le reste du pipeline passe.

---

## Epic 13 — Paiement en espèces pour l'abonnement ✅ Terminé

**Objectif** : ajouter un deuxième mode de paiement de l'abonnement (en plus de MonCash), même principe que pos_api (`BillingPayment.method`, déclaration tenant → confirmation superadmin) — marché haïtien, beaucoup de paiements se font encore en espèces de la main à la main.

- `PaiementAbonnement` (migration `0027`) : `methode` (`moncash`|`especes`), `statut` (`confirme`|`en_attente`|`rejete`). Une déclaration espèces reste `en_attente` — **l'abonnement ne s'active jamais à la seule déclaration**, seulement à la confirmation (sinon n'importe qui pourrait s'auto-activer sans payer).
- `POST /abonnement/declarer-especes` (tenant, Admin) ; `POST /superadmin/paiements/{id}/confirmer|rejeter` ; `GET /superadmin/paiements-en-attente` (vue globale toutes entreprises confondues — sans elle, un paiement en attente n'était visible qu'en ouvrant la fiche de l'entreprise correspondante une par une, aucun moyen de le retrouver sans déjà savoir qui l'a déclaré).
- Web : bouton "Payer en espèces" (écran Abonnement, tenant) ; boutons Confirmer/Rejeter (fiche entreprise superadmin **et** nouvel onglet "Paiements en attente" dans Paramètres superadmin).
- **Bug réel trouvé et corrigé** : `Abonnement.montant` n'était jamais resynchronisé au moment de la confirmation (espèces **ou** MonCash) — si le prix plateforme changeait entre deux paiements, la carte "Plan" du tenant pouvait afficher un montant différent de celui réellement payé dans l'historique. Corrigé aux deux endroits (`confirmer_paiement`, `verifier_abonnement`).
- Reçu d'abonnement (`recu_abonnement_pdf.dart`) refait en facture A4 pleine page (numéro, date, blocs De/Facturé à, détail, sous-total/total) au lieu du format thermique 58/80mm hérité des reçus de collecte — un abonnement annuel B2B se documente comme une facture. Nécessite `initializeDateFormatting('fr')` au démarrage (`main.dart`) pour le format de date en toutes lettres, sinon `LocaleDataException` au premier reçu imprimé.

---

## Epic 14 — Refonte visuelle façon pos_api ✅ Terminé

**Objectif** : demande explicite et répétée de reproduire le style visuel de pos_api (dashboards, cartes, modaux, formulaires) plutôt que le thème d'origine.

- **Dashboards** (superadmin et admin tenant) : fond `#F0F2F5` (au lieu du fond crème du thème), `PosStyleStatCard` (`core/widgets/`, widget partagé) — icône colorée dans un carré arrondi à gauche, label/valeur à droite, reproduction fidèle de `pos_api/frontend/lib/shared/widgets/stat_card.dart`. Mêmes seuils/ratios de grille responsive que `_ResponsiveGrid` de pos_api (xl=1100px→4 colonnes, md=480px→2, sinon 1).
- **Modaux** : les 6 formulaires "bottom sheet" (Ajouter un client, Assigner agent, Nouveau compte Sabotay, Rôle employé, Inviter employé, Nouveau compte superadmin) convertis en `AlertDialog` centrées (`showDialog` au lieu de `showModalBottomSheet`/`DraggableScrollableSheet`) — même structure que `CustomerFormDialog` de pos_api. `DialogThemeData` ajouté au thème global (fond blanc pur, `surfaceTintColor: transparent`) — Material 3 utilise sinon `surfaceContainerHigh`, une surface tonale teintée par défaut.
- **Inputs** : `inputDecorationTheme` global refait (fond blanc `colorScheme.surface`, bordure fine `#E2E8F0` en mode clair — littérale, pas `colorScheme.outline` qui est teinté chaud par le seed doré —, radius 8) — s'applique à toute l'app d'un coup, plus besoin de style local par écran.
- **Sidebar admin persistant** (`ShellRoute`, `app_router.dart` + `AdminShell`/`DashboardContent` dans `core/widgets/dashboard_shell.dart`) : avant ce changement, chaque écran admin construisait sa propre coquille avec sidebar inclus, reconstruite à chaque navigation — le sidebar entier glissait avec le contenu pendant la transition de page. Le sidebar est maintenant monté une seule fois par le `ShellRoute`, seul le contenu de la page transitionne.
- **Bugs réels trouvés et corrigés en cours de route** :
  - Fiche entreprise superadmin plantait systématiquement (`Impossible de charger cette entreprise`) — `SuperAdminUtilisateur.prenom` castait `as String` côté web alors que le champ est nullable côté backend, dès qu'un utilisateur n'a pas de prénom renseigné. Reproduit et confirmé en appelant l'endpoint directement en Python (aucune exception serveur — le bug était uniquement dans le parsing JSON côté web).
  - Boutons d'action ("Ajouter un client", etc.) totalement invisibles en dessous de 900px — l'en-tête de page (titre + action) n'était affiché que sur desktop (`if (isWide)`), et l'AppBar mobile du shell n'avait accès qu'à un titre générique, jamais à `action`. Affiché maintenant à toutes les largeurs, en `Wrap` plutôt qu'en `Row` fixe pour ne pas déborder sur un petit écran.
  - Section "Tarification"/"SMTP Config" (Paramètres superadmin) et fiche entreprise superadmin : chaque état vide (`EmptyState`) flottait directement sur le fond gris de la page — enveloppé dans une Card blanche comme les états non-vides.

---

## Epic 15 — Graphique de statistiques (tableau de bord Admin) ✅ Terminé

**Objectif** : visualiser la collecte, les retraits et la variation du nombre de clients, avec un sélecteur de période (jour/semaine/mois/année) — demandé explicitement.

- `GET /dashboard/serie-temporelle?periode=jour|semaine|mois|annee` — buckets jour (14 derniers, un point par jour) et semaine (8 dernières, fenêtres glissantes de 7 jours) en fenêtre glissante ; mois (12 derniers) et année (5 dernières) alignés sur le calendrier (plus lisible : "Août 2026" plutôt qu'une fenêtre de 30 jours arbitraire). Chaque bucket : montant collecté, montant retiré, nombre de nouveaux clients.
- Web : `StatistiquesChartCard` (`fl_chart`, nouvelle dépendance) — sélecteur de période façon pos_api, un `LineChart` collecte/retrait (deux courbes, même échelle HTG) et un `BarChart` nouveaux clients en dessous. Câble au passage "Total collecté (mois)" (`GET /dashboard/statistiques`, endpoint déjà existant mais jamais consommé côté web — n'affichait qu'un tiret jusqu'ici).
- **Vérifié directement en local** (appel Python direct de l'endpoint, comme pour les autres diagnostics de cette session) : les 4 périodes produisent le bon nombre de buckets et les bons labels.

---

## Epic 16 — Déconnexion automatique sur session expirée ✅ Terminé

**Objectif** : `ACCESS_TOKEN_EXPIRE_MINUTES` (60 min par défaut) fait qu'un token expire en cours de session normale — jusqu'ici, chaque écran affichait son propre message d'erreur générique et trompeur ("Impossible de créer le client", "Impossible de charger les statistiques") au lieu d'indiquer la vraie cause. Trouvé deux fois de suite en diagnostiquant des "bugs" en production qui n'en étaient pas (confirmé via les logs d'accès nginx/gunicorn : `401` sur les requêtes concernées, pas 500).

- Intercepteur `onError` ajouté aux deux clients Dio (staff et superadmin, `core/network/api_client.dart`) : un `401` en dehors de `/auth/login`/`/auth/superadmin-login` (où 401 = identifiants invalides, pas session expirée) déclenche directement `logout()` — le routeur renvoie alors vers l'écran de connexion via `_AuthRefreshNotifier`.
- Au passage : canal par défaut de "Mot de passe oublié" changé de SMS (Twilio, jamais configuré en prod → tombe dans un repli qui journalise seulement, jamais reçu) à Email (SMTP configurable sans redéploiement depuis Superadmin → Paramètres → SMTP Config, voir Epic 9).

---

## Epic 17 — Clients assignés, recherche sur les listes, registre de transactions (web) ✅ Terminé

**Objectif** : trois trous signalés explicitement côté admin web — la fiche employé ne montrait pas ses clients assignés, les listes Clients/Employés n'avaient aucune recherche, et il n'existait aucun moyen de retrouver une transaction précise sans passer par un rapport borné à une période.

### Clients assignés sur la fiche employé
- `web/lib/features/employees/presentation/employee_detail_screen.dart` : nouvelle carte "Clients assignés", filtrée depuis `clientListControllerProvider` déjà chargé (`Client.agentAssigneId == employee.id`) — pas de nouvel endpoint backend nécessaire. Chaque ligne pointe vers la fiche client (`/admin/clients/:id`).

### Recherche sur les listes Clients et Employés
- `admin_clients_screen.dart` / `employee_list_screen.dart` : champ de recherche (nom/téléphone pour les clients, +email pour les employés), filtrage **côté client** sur la liste déjà chargée en mémoire.
- **Pagination volontairement pas ajoutée** : les deux listes sont déjà entièrement chargées en un seul appel (`GET /clients`/`GET /utilisateurs`, sans `skip`/`limit` côté backend) — une vraie pagination serveur demanderait de changer ces deux endpoints. Les volumes actuels ne le justifient pas ; à revisiter si une entreprise dépasse quelques centaines de clients/employés et que le premier chargement devient sensiblement lent.

### Nouvel onglet "Transactions" (registre brut, distinct de "Rapports")
Décidé avec l'utilisateur : "Rapports" (déjà livré, session précédente) reste la synthèse période + totaux + filtre agent ; "Transactions" est un **registre brut** pour retrouver une transaction précise par recherche libre, sans période par défaut.
- Backend : `GET /transactions` (`backend/app/api/v1/endpoints/transactions.py`) — pagination (`skip`/`limit`, max 200), recherche libre (`q`) sur le nom/prénom du client, le numéro de compte (`CompteSabotay.numero_compte`) ou le nom de l'agent (`collecte_par_nom`), via jointure `Transaction ⇄ CompteSabotay ⇄ Client` (`crud/transaction.py::list_registre`). Même règle d'accès que `/transactions/rapport` : un Agent reste forcé sur ses propres transactions.
- Nouveaux schémas `TransactionRegistreItem` (= `TransactionRead` + `client_nom`/`compte_numero` résolus côté serveur) et `TransactionRegistrePage` (`items`/`total`).
- Web : `TransactionRegistreScreen` (`web/lib/features/transactions/presentation/`), recherche avec debounce 400ms, pagination précédent/suivant, nouvel item de sidebar "Transactions" (`/admin/transactions`, entre Tableau de bord et Rapports).
- **Testé de bout en bout via HTTP réel** (pas seulement `py_compile`) : instance uvicorn temporaire lancée sur un port dédié (9099, arrêtée après coup — sans toucher aux serveurs de dev déjà en cours sur 9004/9008), token généré directement via `create_access_token` pour un compte Admin réel de la base de dev locale. Confirmé : liste sans filtre (`total`/`items` corrects), recherche par nom de client (`q=test`), par agent (`q=nike`, insensible à la casse), recherche sans résultat (`q=introuvable` → `items: []`), pagination au-delà du dernier élément (`skip=1` sur 1 résultat → `items: []`, `total` inchangé). Non-régression vérifiée sur `/transactions/rapport` (toujours 200, mêmes données).
- **Point d'attention noté pendant la vérification, pas un bug de ce code** : les deux serveurs de dev déjà en cours (`--reload`, ports 9004/9008) n'ont pas repris ces changements automatiquement (`GET /transactions` renvoyait 405 dessus, alors que l'instance de test fraîchement lancée répondait correctement) — probablement un `--reload` qui ne surveille pas ce dossier depuis leur cwd de lancement. **Un redémarrage manuel de ces deux process est nécessaire avant de tester dans le navigateur.**
- `flutter analyze` (web) 0 erreur, `flutter build web` propre.

---

## Epic 18 — Numéro de reçu lisible + libellé adapté au type de transaction ✅ Terminé

**Objectif** : deux trous signalés explicitement sur les reçus de collecte/retrait (mobile Bluetooth/Sunmi/PDF, web PDF). Le libellé "Collecté par" apparaissait tel quel même sur un reçu de **retrait** (sémantiquement faux — rien n'y est "collecté"). Le numéro de reçu (`Reçu N°`) affichait l'UUID technique de la transaction (`TR-${transaction.id}`), noté comme limite cosmétique connue dans l'Epic 3.

- `backend/app/models/transaction.py` : nouveau champ `numero` (`_generate_numero()`, ex. `TR-20260817143022137` — timestamp à la milliseconde, préfixe fixe). **Choix explicite : pas de compteur séquentiel par tenant** (contrairement à `comptes_sabotay.numero_compte`) — pas de verrou/course à gérer, collision pratiquement impossible même en écritures concurrentes, demandé ainsi par l'utilisateur.
- Migration `0028` : colonne `numero` (non-nullable, index simple, pas de contrainte unique — cosmétique, pas une clé). Rétro-remplissage des lignes existantes depuis leur propre `cree_le` (`to_char(cree_le, 'YYYYMMDDHH24MISSMS')`), pas une valeur unique partagée pour tout l'historique.
- `TransactionRead`/`TransactionRegistreItem` (backend) et `Transaction`/`TransactionRegistreItem` (domain models mobile **et** web) : champ `numero` ajouté.
- Libellé : `isRetrait ? 'Traité par' : 'Collecté par'` dans les 4 générateurs de reçu — `mobile/lib/features/transactions/presentation/recu_pdf.dart`, `mobile/lib/core/printing/bluetooth_print_service.dart`, `mobile/lib/core/printing/thermal_printer_service.dart` (impression Sunmi), `web/lib/features/transactions/presentation/recu_pdf.dart`. `'Reçu N°'` utilise désormais `transaction.numero` dans les 4 mêmes fichiers (plus le nom de fichier du PDF généré, `Recu-${transaction.numero}` au lieu de `Recu-TR-${transaction.id}`).
- **Vérifié que la sync cloud⇄local (Epic 2) n'a rien à mettre à jour manuellement** : `ENTITES` (`sync.py`) référence le modèle `Transaction` directement, la sérialisation push/pull (`model_dump()`/`model_validate()`) est générique — un nouveau champ suit automatiquement des deux côtés (cloud↔local), aucune liste de champs codée en dur trouvée.
- **Risque identifié dans cette session, corrigé dans la session suivante — voir Epic 20.**
- **Testé de bout en bout** : migration `0028` appliquée réellement sur la base de dev Postgres (rétro-remplissage vérifié par `SELECT` — `TR-20260812133954967` cohérent avec `cree_le` = `2026-08-12 13:39:54.967069`), endpoint `GET /transactions` réinterrogé via une instance uvicorn temporaire (port dédié, arrêtée après coup) confirmant `numero` présent et correctement formaté dans la réponse JSON. `flutter analyze` (mobile + web) 0 erreur, `flutter build web` et `flutter build apk --debug` propres.

---

## Epic 19 — Logo entreprise + frais de retrait éditable (web/bureau) ✅ Terminé

**Objectif** : sur l'onglet Entreprise (web, et bureau — même codebase, voir Epic 5c), l'admin doit pouvoir ajouter le logo de son entreprise et configurer le frais de retrait. Le frais existait déjà côté backend (`Entreprise.frais_retrait`, appliqué depuis l'Epic initial) mais son commentaire disait explicitement « pas d'écran de config web dans ce repo pour l'instant » — confirmé : absent de `EntrepriseProfile` (domain), de `updateProfile()` (repository) et du formulaire web. La sémantique du calcul a aussi été vérifiée avant toute modif : elle était déjà correcte (voir ci-dessous), aucun changement de logique financière n'était nécessaire.

### Logo entreprise
- Aucune infra de stockage de fichiers n'existe dans ce repo (ni cloud ni bureau) — **choix délibéré : stocker le logo en data URI base64** (`Entreprise.logo_data`, migration `0029`) plutôt qu'un fichier + URL. `entreprises` fait déjà partie des entités synchronisées (`sync.py::ENTITES`, sérialisation générique `model_dump()`/`model_validate()`) — un champ texte simple traverse ce mécanisme sans rien y ajouter, contrairement à un fichier binaire qu'il aurait fallu transférer séparément entre cloud et poste local.
- Plafond de taille appliqué aux deux bouts : ~1 Mo décodé côté client (`_tailleMaxLogoOctets`, feedback immédiat) et ~1,4 Mo (marge d'encodage base64) côté serveur (`_TAILLE_MAX_LOGO_DATA`, `PATCH /entreprises/profil`) — défense en profondeur, pas seulement l'UI.
- Web : nouveau champ `file_picker` (multiplateforme web/Windows/macOS, `withData: true` pour récupérer les bytes directement) dans `_ProfileInfoCard` (`entreprise_profile_screen.dart`) — aperçu (`Image.memory`) + bouton "Ajouter/Changer le logo", envoyé avec le reste du formulaire au clic sur "Enregistrer" (pas d'auto-save au moment du choix du fichier, cohérent avec le reste du formulaire).
- **Portée volontairement limitée** : uniquement l'upload/affichage dans les réglages. Le logo n'est **pas** branché sur l'impression des reçus (PDF/Bluetooth/Sunmi, Epic "reçus de paiement") — ce serait un epic séparé, plus lourd (conversion bitmap ESC/POS comme pos_api, voir `bluetooth_print_service.dart` de pos_api), non demandé ici.

### Frais de retrait — UI ajoutée, logique déjà correcte
- `EntrepriseProfile` (domain web), `updateProfile()` (repository) et `_ProfileInfoCard` (nouveau `TextFormField` avec texte d'aide explicite) : `frais_retrait` maintenant éditable depuis le web, avec validation (`>= 0`).
- **Sémantique vérifiée avant toute modification** (`crud/transaction.py::create_retrait`/`get_solde`) : `data.montant` (saisi par l'agent) est bien la portion déduite du solde disponible — le client reçoit `montant - frais` net en main. Le plafond de retrait (`data.montant > solde.solde_disponible`) compare directement le montant demandé au solde, sans y ajouter les frais séparément — cohérent avec "le frais sort du montant retiré/du solde", déjà correctement implémenté et déjà visible côté mobile (`retrait_sheet.dart` affiche frais + montant net à remettre avant confirmation). **Aucun changement de cette logique** : le trou était uniquement l'absence d'UI web pour configurer la valeur, pas un bug de calcul.
- Corrigé au passage : deux constructeurs `EntrepriseProfile(...)` (dont un profil minimal reconstruit côté super-admin pour l'impression du reçu d'abonnement, `superadmin_entreprise_detail_screen.dart`) ne fournissaient pas les nouveaux champs obligatoires — `flutter build web` a immédiatement révélé l'erreur de compilation, corrigée (`logoData: null`, `fraisRetrait: 0` pour ce profil minimal, qui n'a de toute façon pas accès à ces données via `EntrepriseSuperAdminRead`).
- **Testé de bout en bout via HTTP réel** (instance uvicorn temporaire dédiée, arrêtée après coup, données de test nettoyées derrière) : `PATCH /entreprises/profil` avec logo + frais → `200`, valeurs bien persistées (vérifié par `GET` + `SELECT` direct) ; logo surdimensionné (~1,5 Mo) → `400` avec message explicite. `flutter analyze` (web) 0 erreur, `flutter build web` **et** `flutter build macos --debug` propres (la cible bureau partage ce code, testée explicitement puisque la demande visait web *et* bureau).

---

## Epic 20 — Garde-fou schéma local (pattern pos_api), palette mobile pos_api, parité sync mobile ✅ Terminé

**Objectif** : trois demandes explicites, chacune inspirée de la façon dont pos_api gère le même problème.

### Garde-fou de schéma SQLite local (risque noté aux Epics 18/19, corrigé ici)
- Recherche préalable dans `pos_api/api/main.py` : pos_api **n'utilise pas non plus Alembic** dans son binaire compilé (`_run_alembic_migrations()`, lignes 167-236, se désactive elle-même via `if getattr(sys, "frozen", False): return` — Alembic a besoin de ses fichiers de migration sur disque, absents d'un exécutable figé). Le vrai mécanisme de pos_api est `_sync_schema_from_models()` (lignes 238-355) : inspecte chaque table existante, compare aux colonnes du modèle, et exécute des `ALTER TABLE ADD COLUMN` pour combler l'écart — exécuté à **chaque démarrage**, en plus de `create_all()`.
- Reproduit à l'identique côté SabotayPro : `backend/app/core/db.py::sync_schema_local()`, appelée juste après `create_all()` dans `main.py::lifespan()` (uniquement en `LOCAL_MODE`). Simplification assumée par rapport à pos_api : colonnes toujours ajoutées **nullable**, même si le modèle Python les déclare `NOT NULL` — un `ADD COLUMN NOT NULL` sans défaut échoue dès que la table contient des lignes, et l'application fournit de toute façon toujours une valeur à la création pour les nouvelles lignes ; seules les lignes déjà existantes avant la mise à jour du poste resteraient à `NULL` sur ce champ (cosmétique, ex. un vieux reçu sans numéro lisible).
- **Testé de bout en bout à trois niveaux**, pas seulement en théorie :
  1. Appel direct de `sync_schema_local()` sur un SQLite simulant un poste "ancien" (schéma créé puis `numero`/`logo_data` retirés via `ALTER TABLE DROP COLUMN`, après avoir dû aussi supprimer l'index associé — SQLite refuse de droper une colonne indexée sans ça, détail découvert pendant le test) → colonnes bien réapparues.
  2. Non-régression sur une base neuve : `create_all()` + `sync_schema_local()` enchaînés ne provoquent aucune erreur (deuxième appel no-op silencieux sur des colonnes déjà présentes).
  3. **Démarrage réel du serveur** (`uvicorn app.main:app`, `LOCAL_MODE=true`) contre la base "ancienne" simulée → logs confirmant `Colonne locale ajoutée : entreprises.logo_data` et `: transactions.numero`, `GET /health` → 200, colonnes vérifiées présentes après coup.

### Palette de couleurs — mobile aligné sur pos_api
- Recherche préalable : pos_api n'a qu'un seul thème (`pos_api/frontend/lib/core/theme.dart`), pas de mode sombre, palette `primary #0077C5`, `accent #2CA01C`, `background #F0F2F5`, `surface #FFFFFF`, `textPrimary #1A202C`, `textSecondary #718096`, `divider #E2E8F0`, `error #E53E3E`, `info #3182CE`.
- `mobile/lib/core/theme/app_colors.dart` : remplace le système "navy/émeraude" de `Model_Mobil_App/DESIGN.md` par cette palette — **noms de constantes conservés à l'identique** (`navy`, `emerald`, `crimson`, `slate`, `lightBg`, etc.) pour ne casser aucun point d'usage dans l'app, seules les valeurs changent. `slate` (bleu "info", `#3182CE`) reprend exactement la couleur déjà utilisée côté web pour la carte "Clients actifs" du tableau de bord (Epic 15) — cohérence de palette entre web et mobile même si le web garde son doré (`gold`) comme couleur de marque principale pour les boutons (Epic 14, non touché ici, pas demandé).
- pos_api n'ayant pas de mode sombre, les variantes `*Dark` (utilisées quand `Brightness.dark`) sont **adaptées, pas copiées** : `navyDark` reprend `sidebarSelected` (`#2563EB`, la teinte que pos_api utilise lui-même pour ressortir sur son sidebar sombre), `emeraldDark` reprend `success` (`#38A169`), `crimsonDark` est éclairci (`#FF6B6B`, pos_api n'a pas d'équivalent). Les neutres du mode sombre (fond/surface/texte, propres à SabotayPro, sans équivalent pos_api) restent inchangés.
- `flutter analyze` 0 erreur, `flutter build apk --debug` propre.

### Frais de retrait et logo — parité de sync mobile vérifiée
- `frais_retrait` : déjà présent et fonctionnel côté mobile avant cette session (`EntrepriseProfil.fraisRetrait`, lu et déjà utilisé pour le calcul du montant net dans `retrait_sheet.dart`) — confirmé, rien à corriger.
- `logo_data` : présent côté backend (Epic 19) mais **absent du domain model mobile** — ajouté à `mobile/lib/features/entreprise/domain/entreprise_profil.dart` pour la parité, même si rien ne l'affiche encore côté mobile (le logo n'est toujours pas branché sur l'impression des reçus, portée volontairement exclue à l'Epic 19).
- Le flux HTTP (`GET /entreprises/profil`) et la sync cloud⇄bureau (générique, voir Epic 18) transportaient déjà ces deux champs correctement pour l'app mobile comme pour un poste bureau — seul le parsing Dart mobile manquait pour `logo_data`, maintenant comblé.

---

## Epic 6 — Offline-first mobile complet ⬜ Pas commencé, pas confirmé prioritaire

Explicitement hors-scope du MVP par le PRD (§5.2 : "Mode hors-ligne (offline-first) pour les agents" listé comme hors scope, prévu Phase 2 du PRD lui-même). L'Epic 1 a livré une résilience partielle (file d'attente pour la collecte en cours). Un offline-first complet (cache local des clients/comptes, agent travaillant une journée entière sans réseau) demanderait le même genre de moteur de sync que l'Epic 2, mais côté mobile (SQLite local + entités mises en cache en lecture) — **à ne pas entamer sans confirmation explicite que c'est maintenant prioritaire**, PRD à jour dit le contraire.
