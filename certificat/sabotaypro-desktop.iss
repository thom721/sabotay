; ============================================================
;  SabotayPro Desktop — Script Inno Setup
;  Génère : SabotayPro-Setup.exe
;
;  Contrairement à pos_api (deux installateurs séparés : pos-server.iss pour
;  le backend headless d'un poste "serveur" LAN, pos-client.iss pour l'UI
;  caisse d'un poste "client" qui parle à ce serveur), SabotayPro cible un
;  seul poste par entreprise (voir Epic 2 dans EPICS.md) : backend + UI
;  desktop sont installés et bundlés ensemble, ici, en un seul .exe.
;
;  Réutilise le même mécanisme de signature Authenticode que pos_api (même
;  certificat, secrets CI WIN_CODESIGN_PFX_BASE64/WIN_CODESIGN_PFX_PASSWORD)
;  — voir /development/pos_api/certificat/pos-server.iss pour la référence.
; ============================================================

#define MyAppName    "SabotayPro"
; Valeur de repli uniquement — le CI passe toujours /DMyAppVersion=$ver.
#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif
#define MyAppPublisher "SabotayPro"
; Même domaine que le lien de synchronisation cloud (voir Env.defaultCloudUrl
; côté web et CLOUD_URL dans le CI).
#define MyAppURL     "https://sabotay.infini-software.cloud"
#define MyAppExeName "sabotaypro.exe"
#define MyServiceExeName "sabotaypro-server.exe"
#define MyServiceName "SabotayProServer"

[Setup]
; GUID généré pour ce nouvel installateur — ne jamais réutiliser celui de pos_api.
AppId={{2E6C1B0E-2E1E-4B7A-9E4C-6C6C6E7C6A1F}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

; Program Files pour l'UI, ProgramData pour les données/service — le service
; Windows (LocalSystem) doit pouvoir écrire son .db SQLite sans dépendre des
; permissions d'un compte utilisateur particulier.
DefaultDirName={autopf}\SabotayPro
DisableDirPage=no
DisableProgramGroupPage=yes

; Droits admin obligatoires (création de service, certutil -addstore Root)
PrivilegesRequired=admin

; Architecture 64 bits uniquement
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

OutputDir=.
OutputBaseFilename=SabotayPro-Setup
SolidCompression=yes
WizardStyle=modern

; Signature Authenticode — commande réelle injectée par le CI via
; /SSabotayProSignTool=... (voir .github/workflows/build.yml), même
; certificat que pos_api (secrets WIN_CODESIGN_PFX_BASE64/_PASSWORD).
SignTool=SabotayProSignTool

[Languages]
Name: "french";  MessagesFile: "compiler:Languages\French.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Créer une icône sur le Bureau"; \
  GroupDescription: "Icônes supplémentaires"

; ── Fichiers à copier ─────────────────────────────────────────────────────────
[Files]
; Backend compilé (Nuitka standalone, voir backend/server_main.py) — "sign"
; applique SabotayProSignTool à cet exe précis pendant la compilation CI.
Source: "backend-windows\{#MyServiceExeName}"; DestDir: "{app}\server"; Flags: ignoreversion sign
Source: "backend-windows\*"; DestDir: "{app}\server"; \
  Flags: ignoreversion recursesubdirs createallsubdirs

; UI desktop Flutter Windows
Source: "frontend-windows\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion sign
Source: "frontend-windows\*"; DestDir: "{app}"; \
  Flags: ignoreversion recursesubdirs createallsubdirs

; Certificat public de signature — installé dans le magasin de confiance
; Windows par le [Run] ci-dessous, puis supprimé (ne reste jamais sur disque).
Source: "setup-info\sabotaypro-codesign.cer"; DestDir: "{tmp}"; \
  Flags: ignoreversion deleteafterinstall

; NSSM (Non-Sucking Service Manager) — enveloppe l'exe backend (simple appli
; console, pas d'implémentation du protocole SCM) en un vrai service Windows.
; Téléchargé par le CI (voir build.yml) avant compilation, même binaire que
; pos_api utilise déjà en production (pos-server.iss / setup-windows.ps1).
Source: "nssm\nssm.exe"; DestDir: "{app}\nssm"; Flags: ignoreversion

; ── Registre Windows ──────────────────────────────────────────────────────────
[Registry]
Root: HKLM; Subkey: "SOFTWARE\SabotayPro"; \
  ValueType: string; ValueName: "InstallPath"; ValueData: "{app}"; \
  Flags: uninsdeletekey
Root: HKLM; Subkey: "SOFTWARE\SabotayPro"; \
  ValueType: string; ValueName: "Version"; ValueData: "{#MyAppVersion}"; \
  Flags: uninsdeletevalue

Root: HKLM; \
  Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\{#MyAppExeName}"; \
  ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName}"; \
  Flags: uninsdeletekey
Root: HKLM; \
  Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\{#MyAppExeName}"; \
  ValueType: string; ValueName: "Path"; ValueData: "{app}"; \
  Flags: uninsdeletevalue

; ── Icônes ────────────────────────────────────────────────────────────────────
[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}";  Filename: "{app}\{#MyAppExeName}"; \
  Tasks: desktopicon

; ── Commandes après installation ──────────────────────────────────────────────
[Run]
; Fait confiance au certificat de signature — même raisonnement que pos_api
; (voir pos-server.iss) : "Root" établit la chaîne de confiance, "TrustedPublisher"
; évite le prompt UAC "Éditeur inconnu" pour les futures mises à jour signées
; par ce même certificat.
Filename: "certutil.exe"; \
  Parameters: "-addstore Root ""{tmp}\sabotaypro-codesign.cer"""; \
  Flags: runhidden waituntilterminated; \
  StatusMsg: "Installation du certificat de signature..."

Filename: "certutil.exe"; \
  Parameters: "-addstore TrustedPublisher ""{tmp}\sabotaypro-codesign.cer"""; \
  Flags: runhidden waituntilterminated; \
  StatusMsg: "Installation du certificat de signature..."

; Enregistre le backend comme service Windows via NSSM. "sc.exe create"
; pointant directement sur l'exe ne fonctionne PAS ici : sabotaypro-server.exe
; est une appli console classique (uvicorn.run() bloquant), pas un vrai
; service Windows — le SCM attend qu'il réponde au protocole de contrôle de
; service (StartServiceCtrlDispatcher), ce qu'il ne fait jamais, et le tue
; après le délai d'attente (erreur 1053). NSSM s'enregistre lui-même comme le
; "vrai" service et relaie vers notre exe — même solution que pos_api.
Filename: "{app}\nssm\nssm.exe"; \
  Parameters: "install ""{#MyServiceName}"" ""{app}\server\{#MyServiceExeName}"""; \
  Flags: runhidden waituntilterminated; \
  StatusMsg: "Enregistrement du service SabotayPro..."

Filename: "{app}\nssm\nssm.exe"; \
  Parameters: "set ""{#MyServiceName}"" AppDirectory ""{app}\server"""; \
  Flags: runhidden waituntilterminated

Filename: "{app}\nssm\nssm.exe"; \
  Parameters: "set ""{#MyServiceName}"" DisplayName ""SabotayPro Server"""; \
  Flags: runhidden waituntilterminated

Filename: "{app}\nssm\nssm.exe"; \
  Parameters: "set ""{#MyServiceName}"" Description ""Serveur API local pour SabotayPro"""; \
  Flags: runhidden waituntilterminated

Filename: "{app}\nssm\nssm.exe"; \
  Parameters: "set ""{#MyServiceName}"" Start SERVICE_AUTO_START"; \
  Flags: runhidden waituntilterminated

Filename: "{app}\nssm\nssm.exe"; \
  Parameters: "start ""{#MyServiceName}"""; \
  Flags: runhidden waituntilterminated; \
  StatusMsg: "Démarrage du service SabotayPro..."

; Proposer de lancer l'application après installation
Filename: "{app}\{#MyAppExeName}"; \
  Description: "Démarrer SabotayPro maintenant"; \
  Flags: nowait postinstall skipifsilent

; ── Commandes à la désinstallation ────────────────────────────────────────────
; nssm remove (pas sc delete) — nettoie aussi les paramètres qu'il a stockés
; lui-même sous la clé de service (AppDirectory, etc.), même pattern que
; pos_api à la désinstallation (voir pos-server.iss).
[UninstallRun]
Filename: "{app}\nssm\nssm.exe"; Parameters: "stop ""{#MyServiceName}"""; \
  Flags: runhidden waituntilterminated
Filename: "{app}\nssm\nssm.exe"; Parameters: "remove ""{#MyServiceName}"" confirm"; \
  Flags: runhidden waituntilterminated

; ── Code Pascal ────────────────────────────────────────────────────────────────
[Code]
// Arrête ET désinscrit le service avant la copie des fichiers — évite un exe
// verrouillé en cas de réinstallation/mise à jour (même raisonnement que
// PrepareToInstall dans pos-server.iss, simplifié : un seul service ici,
// pas besoin de la confirmation utilisateur (MsgBox) que fait pos_api pour
// son trio nginx+API+MySQL). "sc.exe delete" (pas nssm.exe) volontairement :
// fonctionne quelle que soit la façon dont le service a été enregistré
// (anciennes versions ≤ v0.4.0 via "sc create" brut, ou nssm.exe désormais)
// — sans ça, le "nssm install" du [Run] échouerait sur un nom déjà pris lors
// d'une mise à jour depuis une version antérieure à ce correctif.
function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ResultCode: Integer;
begin
  Result := '';
  Exec(ExpandConstant('{sys}\sc.exe'), 'stop "{#MyServiceName}"', '', SW_HIDE,
       ewWaitUntilTerminated, ResultCode);
  Exec(ExpandConstant('{sys}\sc.exe'), 'delete "{#MyServiceName}"', '', SW_HIDE,
       ewWaitUntilTerminated, ResultCode);
end;

// ── Fichier de configuration ──────────────────────────────────────────────────
// Le backend lit .env depuis son propre dossier au démarrage (chemin relatif,
// voir server_main.py::_fix_workdir()) — généré ici avec une SECRET_KEY
// propre à cette installation. LOCAL_MODE=true, SQLite (pas de MySQL/Postgres
// côté poste local, décision explicite de ce projet — voir EPICS.md Epic 2).
// CLOUD_SYNC_URL/CLOUD_SYNC_TOKEN restent vides : la liaison au cloud via le
// code d'installation (Admin → Entreprise → Code d'installation,
// POST /sync/redeem-code) se fait au premier lancement de l'application, pas
// ici — voir Epic 5f (implémenté depuis, voir EPICS.md).
procedure CurStepChanged(CurStep: TSetupStep);
var
  EnvPath, SecretKey: String;
  EnvFile: TArrayOfString;
begin
  if CurStep = ssPostInstall then
  begin
    EnvPath := ExpandConstant('{app}\server\.env');
    SecretKey := GetSHA1OfString(GetDateTimeString('yyyymmddhhnnsszzz', #0, #0) + ExpandConstant('{app}'));

    SetArrayLength(EnvFile, 5);
    EnvFile[0] := 'LOCAL_MODE=true';
    EnvFile[1] := 'LOCAL_DATABASE_PATH=./sabotay_local.db';
    EnvFile[2] := 'SECRET_KEY=' + SecretKey;
    EnvFile[3] := 'SERVER_HOST=127.0.0.1';
    EnvFile[4] := 'SERVER_PORT=9004';

    SaveStringsToFile(EnvPath, EnvFile, False);
  end;
end;
