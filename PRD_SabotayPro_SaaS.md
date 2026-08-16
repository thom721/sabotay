# PRD — SabotayPro
### Plateforme SaaS de gestion d'épargne rotative (Sabotay/Sol) pour institutions financières informelles

**Version :** 1.4 (Draft)
**Date :** 29 juillet 2026 (mise à jour le 1 août 2026 — §5.3, §13, §8.2, §8.3, §8.5, §8.8 ; mise à jour le 5 août 2026 — §7.5, §8.3, §8.4, §8.8, §10 ; mise à jour le 16 août 2026 — §8.9)
**Statut :** À valider

---

## 1. Résumé exécutif

SabotayPro est une plateforme SaaS multi-tenant qui permet à des entreprises offrant des services d'épargne rotative de type **Sabotay** (et Sol) en Haïti de digitaliser la gestion de leurs clients, comptes d'épargne, agents de collecte et opérations financières.

Chaque entreprise cliente ("tenant") s'inscrit sur la plateforme et obtient son propre espace isolé pour gérer :
- ses **employés** (agents de collecte, managers, admin)
- ses **clients** (souscripteurs de comptes Sabotay)
- ses **comptes d'épargne** (paramètres, cotisations, retards/dettes)
- ses **rapports et son suivi financier**

Le modèle économique de SabotayPro est un **abonnement SaaS** facturé aux entreprises (par palier, selon le nombre de clients/agents gérés).

---

## 2. Contexte et problème

En Haïti, le **Sabotay** (comme le **Sol**) est un mécanisme d'épargne informelle très répandu, fonctionnant comme une tontine ou une "banque informelle" : un client s'engage à verser un montant fixe chaque jour, pendant une durée déterminée (30 jours, 1 an, etc.), collecté en personne par un agent de terrain. Un jour manqué reste dû — la dette s'accumule.

Aujourd'hui, ces opérations sont gérées **manuellement** (carnets papier, cahiers de comptes, mémoire des agents), ce qui entraîne :
- Absence de traçabilité fiable des paiements et des retards
- Risque d'erreurs, de fraude, ou de perte de données
- Aucune visibilité en temps réel pour le propriétaire de l'entreprise
- Difficulté à faire confiance / scaler l'activité au-delà d'un cercle restreint

**Opportunité :** offrir aux petites entreprises et organisateurs de Sabotay un outil numérique simple, adapté à leur réalité opérationnelle (collecte cash sur le terrain), pour professionnaliser et sécuriser cette activité.

---

## 3. Vision produit

> Devenir l'infrastructure numérique de référence pour la gestion des systèmes d'épargne rotative informels en Haïti et dans la Caraïbe, en donnant aux petites institutions financières les mêmes outils de gestion que les banques formelles — sans complexité inutile.

---

## 4. Utilisateurs cibles (Personas)

| Persona | Description | Besoin principal |
|---|---|---|
| **Admin Entreprise** (propriétaire) | Dirige l'entreprise offrant le service Sabotay | Vue d'ensemble complète, gestion des employés/clients/comptes, contrôle financier |
| **Manager / Superviseur** | Supervise une équipe d'agents ou une zone géographique | Suivi des performances des agents, validation des collectes, rapports de zone |
| **Agent de collecte** | Employé de terrain qui collecte le cash auprès des clients chaque jour | Liste de ses clients du jour, enregistrement rapide des cotisations, vue des retards |
| **Client** | Souscripteur d'un compte Sabotay | Consulter son solde, son historique de paiement, ce qu'il doit, la date de fin de son compte |

---

## 5. Portée du MVP

### 5.1 Dans le scope du MVP

- Inscription et onboarding d'une entreprise (multi-tenant)
- Gestion des employés avec rôles (Admin / Manager / Agent)
- Gestion des clients (création, profil, assignation à un agent)
- Création de **comptes Sabotay** configurables :
  - Montant fixe journalier
  - Durée dynamique (ex. 30 jours, 90 jours, 365 jours...)
  - Calcul automatique de la date de fin et du montant total attendu
- Enregistrement quotidien des cotisations (par l'agent, en cash)
- Suivi automatique des **jours manqués → dette accumulée**
- Tableau de bord Admin (vue globale : montant collecté, clients actifs, retards, agents actifs)
- Tableau de bord Agent (ses clients du jour, statut de collecte)
- Espace **Client en lecture seule** (solde, historique, montant dû, date de fin)
- Rapports de base exportables (liste des retards, résumé journalier/mensuel)
- Facturation SaaS simple (plans d'abonnement par palier)
- Interface bilingue **Français / Créole haïtien**

### 5.2 Hors scope du MVP (voir roadmap)

- Paiement mobile (MonCash, etc.) — collecte reste 100% cash en MVP
- Mode hors-ligne (offline-first) pour les agents
- Notifications automatiques (SMS/WhatsApp)
- Gestion de commissions/rémunération des agents
- Multi-succursales / multi-zones avancées
- API publique / intégrations comptables

### 5.3 Répartition Web / Application mobile

SabotayPro repose sur un seul code applicatif (Flutter), décliné sur Web, Android et iOS. Le
**comportement diffère selon la plateforme**, pas selon des projets séparés :

| Fonctionnalité | Web | App mobile (Android / iOS) |
|---|:---:|:---:|
| Connexion (tous rôles : Admin, Manager, Agent) | ✅ | ✅ |
| Interface adaptée au rôle et aux permissions (RBAC §6) | ✅ | ✅ |
| Inscription d'une nouvelle entreprise (§7.1) | ✅ | ❌ (redirige vers le web) |
| Réinitialisation du mot de passe | ✅ | ❌ (redirige vers le web) |

**Pourquoi :** l'inscription d'une entreprise et la réinitialisation d'un mot de passe sont des
opérations peu fréquentes, plus sûres à traiter sur le canal web ; sur mobile, un employé reçoit
déjà ses identifiants de son Admin, qui gère aussi les accès.

**Priorité d'implémentation :** le Web est modélisé et construit en premier ; les particularités
mobiles (cache local et synchronisation, voir §13 Phase 2) suivent dans une phase ultérieure.

---

## 6. Rôles et permissions (RBAC)

| Fonctionnalité | Admin Entreprise | Manager | Agent | Client |
|---|:---:|:---:|:---:|:---:|
| Inscrire l'entreprise / paramètres globaux | ✅ | ❌ | ❌ | ❌ |
| Gérer les employés (créer/désactiver) | ✅ | ⚠️ Lecture seule | ❌ | ❌ |
| Créer/modifier un client | ✅ | ✅ | ⚠️ Création seule | ❌ |
| Créer un compte Sabotay | ✅ | ✅ | ⚠️ Selon config. | ❌ |
| Enregistrer une cotisation quotidienne | ✅ | ✅ | ✅ | ❌ |
| Voir tous les comptes/clients de l'entreprise | ✅ | ⚠️ Sa zone/équipe | ⚠️ Ses clients assignés | ❌ |
| Voir rapports financiers globaux | ✅ | ⚠️ Sa zone | ❌ | ❌ |
| Consulter son propre compte | ❌ | ❌ | ❌ | ✅ |
| Gérer facturation SaaS de l'entreprise | ✅ | ❌ | ❌ | ❌ |

---

## 7. Parcours utilisateurs clés

**7.1 Inscription d'une entreprise**
Entreprise remplit un formulaire (nom, secteur, devise, contact) → validation email/téléphone → création de l'espace tenant → choix du plan d'abonnement → invitation des premiers employés.

**7.2 Création d'un compte Sabotay pour un client**
Agent/Manager/Admin crée le profil client → sélectionne "Nouveau compte Sabotay" → configure montant journalier + durée → le système calcule automatiquement la date de fin, le montant total attendu, et génère le calendrier de cotisations → compte activé.

**7.3 Collecte quotidienne (agent)**
Agent ouvre sa liste de clients du jour → sélectionne un client → confirme le paiement reçu (montant, date) ou marque "non payé" → le système met à jour le solde et, si non payé, ajoute le montant à la dette du client.

**7.4 Suivi des retards**
Le système identifie automatiquement les comptes en retard (jours manqués cumulés) → alerte visible sur le dashboard Admin/Manager → agent voit la dette lors de sa prochaine visite.

**7.5 Fin de cycle**
À la date de fin prévue (ou une fois le montant total atteint), le compte passe au statut "Complété" → l'Admin/Agent enregistre le retrait du client directement sur la plateforme (§8.4). Quand un retrait ramène le solde disponible du compte à 0, celui-ci passe automatiquement au statut "Inactif" — le compte et tout son historique de transactions restent consultables, rien n'est supprimé.

---

## 8. Exigences fonctionnelles détaillées

### 8.1 Gestion multi-tenant (Entreprises)
- Inscription self-service avec vérification (email/téléphone)
- Isolation stricte des données entre entreprises (aucun accès croisé)
- Paramètres entreprise : nom, logo, devise (HTG par défaut), fuseau horaire
- Statut d'abonnement (actif, essai gratuit, suspendu)

### 8.2 Gestion des employés
- Créer/inviter un employé avec un rôle (Admin, Manager, Agent)
- Fiche employé : nom, prénom, date de naissance, NIF/CIN, adresse, téléphone, email (email obligatoire à l'invitation — sert d'identifiant de connexion et de canal de provisioning)
- À l'invitation, un mot de passe temporaire est généré automatiquement et envoyé par email ; l'employé doit le changer dès sa première connexion (aucun mot de passe saisi manuellement par l'Admin)
- Un Admin ne peut ni désactiver son propre compte, ni changer son propre rôle (protection anti-auto-verrouillage)
- Désactiver/réactiver un compte employé, changer le rôle d'un employé existant
- Assigner des clients à un agent spécifique
- Historique d'activité par employé (audit léger)

### 8.3 Gestion des clients
- Fiche client : nom, prénom, téléphone, email (optionnel), adresse, date de naissance, NIF/CIN, photo (optionnel), agent assigné, héritier/bénéficiaire (nom, prénom, adresse, téléphone)
- Si un email est renseigné, un compte d'accès à l'espace client est provisionné automatiquement (mot de passe temporaire envoyé par email, changement obligatoire à la première connexion) — sans email, le client est géré normalement mais n'a pas d'accès portail
- **Détection de doublon à la création (web uniquement)** : si le nom + prénom + date de naissance (ou le NIF/CIN) correspondent déjà à un client existant dans la même entreprise, la création est bloquée et l'Admin/Manager/Agent est redirigé vers la fiche du client existant pour lui créer un nouveau compte Sabotay plutôt que de dupliquer sa fiche. La comparaison est scopée à l'entreprise (aucune vérification cross-tenant, cohérent avec l'isolation §8.1).
- Historique de tous les comptes Sabotay d'un client (actifs et passés)
- Recherche/filtre des clients (par agent, statut, retard)

### 8.4 Gestion des comptes Sabotay
- Paramètres configurables par compte :
  - Montant fixe journalier
  - Durée en jours (valeur libre — 30, 90, 365, etc.)
  - Date de début
- Calculs automatiques : date de fin, montant total attendu, montant collecté à date, solde restant, jours manqués
- Statuts de compte : Actif, En retard, Complété, Annulé, **Inactif** (atteint automatiquement quand un retrait ramène le solde disponible à 0 — voir §7.5 ; le compte reste visible avec tout son historique)
- Historique complet des transactions (cotisations) par compte

### 8.5 Collecte des paiements
- Interface simple et rapide pour l'agent (optimisée mobile/terrain)
- Enregistrement en un clic : Payé / Non payé, avec horodatage
- Impossible de modifier une transaction déjà validée sans passer par un Manager/Admin (traçabilité)
- Paramétrage du reçu (Admin, indépendant des infos entreprise) : format d'impression (POS thermique 58mm ou 80mm), texte personnalisé de bas de reçu
- Contenu prévu du reçu imprimé (à construire avec l'écran de collecte) : date du dépôt, montant, nom du client, nom de l'employé ayant collecté, montant cumulé, jours restants, jours dus/en retard le cas échéant, texte de bas de reçu

### 8.6 Suivi des retards et dettes
- Calcul automatique de la dette = somme des jours manqués × montant journalier
- Vue "clients en retard" filtrable par agent/zone
- Indicateur visuel de sévérité du retard (nombre de jours consécutifs manqués)

### 8.7 Rapports et tableaux de bord
- Dashboard Admin : total collecté (jour/semaine/mois), nombre de comptes actifs, taux de retard global, performance par agent
- Dashboard Manager : idem, filtré sur son équipe/zone
- Export CSV/PDF des rapports de base

### 8.8 Espace Client (libre-service)
- Connexion par email + mot de passe (mot de passe temporaire fourni par email à la création du profil client, changement obligatoire à la première connexion) — disponible uniquement si un email a été renseigné sur la fiche client
- Vue : solde actuel, montant dû, historique des paiements, date de fin prévue
- Un client peut avoir plusieurs comptes Sabotay au sein d'une même entreprise (ex. plusieurs objectifs d'épargne en parallèle) ; un sélecteur permet de basculer de l'un à l'autre sans reconnexion
- **Identité liée entre entreprises** : un même client (même email) peut être inscrit dans plusieurs entreprises Sabotay différentes — chaque entreprise garde sa propre fiche client, mais un sélecteur permet au client de basculer d'une entreprise liée à l'autre sans ressaisir son mot de passe à chaque fois. Par sécurité/consentement, une entreprise liée n'apparaît dans ce sélecteur qu'après une connexion directe et réussie à cette entreprise au moins une fois (empêche qu'un admin inscrivant un client avec un email déjà connu ailleurs ne le lie silencieusement sans que le client n'ait prouvé connaître son propre mot de passe pour ce compte-là)
- Lecture seule (aucune modification possible côté client en MVP)

### 8.9 Facturation SaaS
- Plans d'abonnement par palier (ex. selon nombre de clients actifs gérés) — *toujours à valider (§11), pas encore implémenté : ce qui existe est un prix annuel unique, configurable par le super-admin (`PlatformConfig`), pas de paliers*
- Page de facturation simple pour l'Admin Entreprise — implémenté (écran Abonnement, historique des paiements, reçu imprimable)
- Période d'essai gratuit configurable — implémenté (`PlatformConfig.essai_jours`)
- **Deux modes de paiement implémentés** : MonCash (automatique, vérification en ligne) et espèces (déclaration par l'Admin Entreprise, confirmée manuellement par le super-admin avant activation — voir EPICS.md Epic 13). Pas dans la portée MVP d'origine (§5.2, "collecte reste 100% cash" — qui concerne la collecte agent↔client, pas la facturation SaaS entreprise↔plateforme, sans rapport).

---

## 9. Exigences non-fonctionnelles

- **Connectivité :** application web responsive, utilisable sur smartphone/tablette bas de gamme — connexion internet requise pour le MVP (le mode hors-ligne est en roadmap, point critique compte tenu de la réalité du réseau en Haïti)
- **Langues :** Français et Créole haïtien dès le MVP
- **Devise :** Gourde haïtienne (HTG) par défaut, extensible à d'autres devises
- **Sécurité :** isolation des données par tenant, authentification sécurisée, chiffrement des données sensibles, journal d'audit des actions critiques (création/modification de compte, transactions)
- **Performance :** interface de collecte utilisable en < 3 secondes par transaction (agents avec beaucoup de clients à voir par jour)
- **Disponibilité :** hébergement cloud avec objectif de disponibilité 99%+

---

## 10. Modèle de données (haut niveau)

| Entité | Attributs clés |
|---|---|
| **Entreprise (Tenant)** | id, nom, devise, plan_abonnement, statut, date_creation |
| **Utilisateur** | id, entreprise_id, nom, rôle, téléphone, statut |
| **Client** | id, entreprise_id, nom, téléphone, adresse, agent_assigné_id |
| **CompteSabotay** | id, client_id, montant_journalier, date_debut, duree_jours, date_fin_prevue, montant_total_attendu, statut (actif / en_retard / complete / annule / inactif) |
| **Transaction** | id, compte_id, date, montant, statut (payé/manqué), collecté_par_id |
| **Abonnement** | id, entreprise_id, plan, date_debut, date_renouvellement, statut |

---

## 11. Modèle SaaS / Monétisation (à valider)

Suggestion de structure par paliers (à ajuster selon étude de marché) :

| Plan | Cible | Limite indicative | Prix suggéré |
|---|---|---|---|
| Starter | Petit organisateur, 1-2 agents | Jusqu'à 100 comptes actifs | À définir |
| Pro | PME établie | Jusqu'à 500 comptes actifs | À définir |
| Business | Entreprise multi-agents/zones | Illimité + rapports avancés | À définir |

*Point ouvert : faut-il aussi prévoir une commission sur volume collecté en plus/à la place d'un abonnement fixe ?*

---

## 12. Métriques de succès (KPIs)

- Nombre d'entreprises inscrites et actives
- Taux de rétention mensuelle des entreprises (churn SaaS)
- Nombre total de comptes Sabotay actifs gérés sur la plateforme
- Taux de collecte quotidienne (% de cotisations attendues effectivement enregistrées)
- Taux de résolution des retards (dettes remboursées vs accumulées)
- Volume total (HTG) transitant par la plateforme

---

## 13. Roadmap

### Phase 1 — MVP (voir section 5.1)
Objectif : valider le produit avec un nombre restreint d'entreprises pilotes.

### Phase 2 — Consolidation
- Mode hors-ligne pour l'app mobile : base **SQLite locale** sur l'appareil de l'agent, avec
  synchronisation automatique vers le serveur web dès qu'une connexion est disponible (voir §5.3)
- Intégration paiement mobile (MonCash)
- Intégration paiement mobile (MonCash)
- Notifications SMS/WhatsApp (rappels clients, alertes retard aux managers)
- Gestion des commissions/rémunération des agents
- Gestion multi-succursales et zones géographiques
- Rapports avancés (tendances, prévisions de collecte)

### Phase 3 — Extension
- API publique / intégrations comptables externes
- Score de fiabilité client basé sur l'historique de paiement
- Support de produits d'épargne additionnels (Sol classique, autres variantes)
- Conformité réglementaire renforcée / reporting pour régulateurs financiers
- Expansion géographique (autres pays de la Caraïbe avec systèmes similaires)

---

## 14. Risques et hypothèses

| Risque/Hypothèse | Impact | Mitigation |
|---|---|---|
| Connectivité internet instable en zone rurale | Élevé | Priorité haute au mode hors-ligne en Phase 2 |
| Résistance au changement (habitude du carnet papier) | Moyen | Interface ultra-simple, onboarding accompagné |
| Confiance des clients dans un système numérique remplaçant le cash | Moyen | Espace client transparent, historique consultable à tout moment |
| Absence de cadre réglementaire clair pour ces institutions informelles | Moyen-Élevé | Veille réglementaire, PRD Phase 3 inclut la conformité |

---

## 15. Questions ouvertes à valider avec les parties prenantes

1. Y a-t-il une commission/frais prélevé par l'entreprise sur le montant collecté (comme dans certains modèles de Sol) ?
2. Comment le remboursement final au client est-il géré — via la plateforme ou hors-plateforme (manuel) en MVP ?
3. Quel est le nombre d'entreprises pilotes visées pour le lancement du MVP ?
4. Quel budget/délai est envisagé pour la Phase 1 ?
5. Faut-il un système de garantie/caution pour les agents de collecte (risque de vol/fraude du cash collecté) ?

---

*Document à itérer avec les parties prenantes avant le passage en phase de conception technique (spécifications techniques, wireframes, architecture).*
