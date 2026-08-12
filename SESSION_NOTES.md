# SabotayPro — Notes de session (5-6 août 2026)

Document de suivi de travail, pas un document produit — le PRD (`PRD_SabotayPro_SaaS.md`, à jour en v1.3) reste la référence fonctionnelle.

## Architecture confirmée cette session

**Trois espaces distincts, un seul stack Flutter :**
- **`mobile/`** — app mobile, sert à la fois le personnel (Admin/Manager/Agent) ET le portail client libre-service (`features/client_portal/`).
- **`web/`** — aujourd'hui : Admin/Manager (gestion) + Super Admin (plateforme). **Décision de cette session : `web/` doit aussi accueillir un deuxième espace, pour les Clients, avec les fonctionnalités 100% identiques au portail client mobile** (dashboard, historique, profil, sélecteur de compte Sabotay, sélecteur d'entreprise liée). Pas encore commencé — voir "À faire".
- **`backend/`** — FastAPI, seule source de vérité, partagée par les trois.

## Fait cette session

### Compte client de test
- `client.test@sabotay.test` / `Test1234!` → entreprise "Sabotay Test SA" (id 3, client id 10)
- même email / `TestBis5678!` → entreprise "Sabotay Test QA2" (id 4, client id 11)
- ⚠️ mots de passe de test réinitialisés en cours de route (pas les vrais comptes de prod) : admin "Nike Occean" (tél. 50900000001) → `TestAdmin1234!` ; super-admin de test `testsa2@sabotaypro.internal` (compte déjà inactif) → `TestSuper1234!`. Le vrai compte super-admin actif (`superadmin@sabotaypro.internal`) n'a pas été touché.
- **Entreprise "Test Sabotay Co" (id 2)** — abonnement au statut `ESSAI` (pas `ACTIF`), **période d'essai expirée** (`date_creation` reculée à 20 jours, au-delà des 14 jours par défaut) : utile pour tester le flux de blocage 402 / paiement en conditions réelles d'essai terminé (voir "Durée d'essai configurable" ci-dessous). Admin "Nike Admin", tél. `50912345678`, mot de passe réinitialisé → `TestEssai1234!`.

### Backend
- **Connexion client multi-entreprise** : un même email peut être `Client` dans plusieurs entreprises. `POST /auth/client-login` ne plante plus (bug corrigé, ancien code faisait un `scalar_one_or_none()` global). Nouveaux endpoints `GET /clients/moi/entreprises-liees` et `POST /clients/moi/switch-entreprise` (bascule sans re-saisir le mot de passe).
- **Garde-fou de consentement** : une entreprise liée n'apparaît dans le sélecteur qu'après une connexion *directe* réussie à cette entreprise au moins une fois (`derniere_connexion IS NOT NULL`) — empêche qu'un admin d'une autre entreprise inscrivant le même email ne lie silencieusement un compte sans preuve que le client connaît son propre mot de passe.
- **Détection de doublon client (création, `POST /clients`)** : bloque (409) si nom+prénom+date de naissance ou nif/cin correspondent déjà à un client de la même entreprise ; réponse inclut l'id du client existant pour rediriger vers "créer un compte Sabotay" au lieu de dupliquer.
- **Statut de compte "Inactif"** : nouvelle valeur d'enum `StatutCompte.INACTIF` (migration `0013`). Un retrait qui ramène `solde_disponible` à 0 bascule automatiquement le compte en inactif — historique toujours visible, rien supprimé.
- **Prix d'abonnement modifiable par le super admin** : nouvelle table singleton `platform_config` (migration `0014`), endpoints `GET`/`PATCH /superadmin/config`. Le prix est maintenant un seul réglage global (pas par entreprise) qui pilote à la fois le message de blocage 402 (`_abonnement_actif` dans `transactions.py`) et le montant réellement envoyé à MonCash (`payer_abonnement`) — avant cette session ces deux endroits étaient déconnectés (l'un lisait `.env`, l'autre un texte codé en dur "100 HTG").
- Vérifié : l'abonnement bloque bien la collecte (`POST /transactions`) mais jamais le retrait (`POST /transactions/retrait`) — comportement voulu, testé en direct.
- **Durée d'essai gratuit configurable par le super admin** (migration `0015`, colonne `platform_config.essai_jours`, défaut 14) — avant cette session, le statut `ESSAI` bloquait la collecte immédiatement et indéfiniment (pas de fenêtre de grâce du tout). `_abonnement_actif` (`transactions.py`) calcule maintenant la limite comme `Entreprise.date_creation + essai_jours` ; dans cette fenêtre, la collecte est autorisée même sans abonnement payé. `PATCH /superadmin/config` accepte maintenant `abonnement_montant_htg` **et** `essai_jours` ensemble (même dialog web, `superadmin_entreprises_screen.dart`).

### Mobile
- Sélecteur d'entreprise liée + sélecteur de compte Sabotay ajoutés au drawer client (`client_nav_drawer.dart`), avec le nom de l'entreprise active affiché (drawer + AppBar du dashboard).
- **Bug corrigé** : `app_router.dart` recréait tout le `GoRouter` à chaque changement d'état client (`ref.watch` au lieu de `ref.read` dans `redirect`) → flash visible par l'écran de connexion à chaque changement d'entreprise. Corrigé.
- **Bug corrigé** : le drawer naviguait entre Dashboard/Historique/Profil via `Navigator.push` brut, en dehors de `go_router` → désynchronisation → "Assertion failed" au clic. Remplacé par `context.go(...)`.

### PRD
Mis à jour en v1.3 — §7.5, §8.3, §8.4, §8.8, §10 (voir le fichier directement pour le détail).

### Portail Client sur le web (nouveau module `web/lib/features/client_portal/`)
- Calqué sur `mobile/lib/features/client_portal/`, mais avec une mise en page web (barre latérale `ClientPortalShell`, plutôt que le `Drawer` mobile) et une connexion séparée : route `/client/login` dédiée (pas de toggle Employé/Client comme sur mobile), lien discret "Espace Client" ajouté à la page d'accueil (`home_screen.dart`).
- Écrans : login, dashboard (solde, jours restants/manqués, sélecteur de compte), historique (avec impression de reçu PDF), profil (changement de mot de passe), changement de mot de passe forcé. Sélecteur d'entreprise liée dans la barre latérale.
- **Nouveau module `web/lib/features/transactions/`** (n'existait pas du tout côté web avant, même pour l'Admin) — `domain/transaction.dart` (juste `Transaction`/`TypeTransaction`, pas `Rapport`, non utilisé ici) et `presentation/recu_pdf.dart` (port de `imprimerRecu`). Dépendances `pdf`/`printing` ajoutées à `web/pubspec.yaml`.
- **Bug latent corrigé au passage** : `web/lib/features/comptes/domain/compte_sabotay.dart` était désynchronisé du backend — il manquait `numero_compte` sur `CompteSabotay`, et `montant_retire`/`solde_disponible` sur `CompteSolde` (présents dans `backend/app/schemas/compte_sabotay.py` et déjà utilisés côté mobile). Corrigé ; aucun autre call site ne construisait ces classes autrement que via `.fromJson`, donc sans risque de régression.
- Staff et Client partagent le même `tokenStorageProvider` (comme sur mobile) — `client_login_screen.dart` et `login_screen.dart` (staff) s'effacent mutuellement l'état en cache (`clearSilently()`, ajouté au passage sur `AuthController` staff qui ne l'avait pas) après une connexion réussie, pour éviter qu'une session résiduelle ne s'affiche.
- `flutter analyze` passe sans erreur sur `web/`. **Pas testé dans le navigateur** (rappel ci-dessous : `flutter run -d chrome` échoue dans cet environnement) — reste à faire par l'utilisateur.

## Point ouvert / pas confirmé résolu

- **"Solde indisponible" sur le dashboard client, spécifiquement sur Sabotay Test QA2.** Le backend répond correctement en direct pour ce cas exact (testé via curl) — cause encore non identifiée côté app si ça persiste après un pull-to-refresh. Le nouveau portail Client web reproduit la même logique (`clientCompteSoldeProvider`) — à vérifier si le problème s'y manifeste aussi une fois testé.

## À faire demain

1. ~~Portail Client sur le web~~ — fait cette session (voir ci-dessus), **reste à tester dans le navigateur** : connexion (`client.test@sabotay.test` / `Test1234!`), dashboard/historique/profil, bascule d'entreprise liée (`TestBis5678!`), impression de reçu, et vérifier qu'aucun résidu de session ne subsiste en alternant connexion staff ↔ Client.
2. **Section "Abonnement" dans le drawer Admin (web)** — détails de l'abonnement de l'entreprise + historique des paiements + impression de reçus de paiement. À explorer : y a-t-il déjà un historique de paiement stocké (aujourd'hui `Abonnement` n'a qu'un seul `date_paiement`, pas une liste) ? Probablement besoin d'une nouvelle table `PaiementAbonnement` si on veut un vrai historique multi-paiements (renouvellements successifs).
3. **Gestion des emails** — deux volets à clarifier avec l'utilisateur avant de coder : emails clients (bienvenue/mot de passe temporaire — le mécanisme existe déjà mais SMTP n'est pas configuré, tombe sur un fallback qui journalise) et emails entreprises (à définir : notifications d'abonnement ? factures ? autre ?).

## Rappels utiles pour reprendre

- Backend en dev : toujours faire un **redémarrage complet** (`taskkill` puis `./.venv/Scripts/python.exe run.py`) après des changements de code plutôt que compter sur le `--reload` d'uvicorn — plusieurs fois cette session le rechargement automatique n'a pas pris, servant du code périmé silencieusement (500 sur des routes pourtant corrigées).
- Idem côté Flutter (mobile) : un **hot restart complet** est nécessaire après ajout de fichiers/nouvelles valeurs d'enum — le hot reload ne les prend pas toujours en compte correctement.
- Le lancement de `flutter run -d chrome` échoue systématiquement dans cet environnement (bloqué sur "Waiting for connection from debug service on Chrome") — impossible pour moi de lancer/tester l'app moi-même ici ; toujours besoin que l'utilisateur lance et teste de son côté.
