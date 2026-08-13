import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/env.dart';

import '../../features/abonnement/presentation/abonnement_screen.dart';
import '../../features/auth/domain/user.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/force_password_change_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/client_portal/presentation/client_auth_controller.dart';
import '../../features/client_portal/presentation/client_dashboard_screen.dart';
import '../../features/client_portal/presentation/client_force_password_change_screen.dart';
import '../../features/client_portal/presentation/client_historique_screen.dart';
import '../../features/client_portal/presentation/client_login_screen.dart';
import '../../features/client_portal/presentation/client_profil_screen.dart';
import '../../features/clients/presentation/admin_clients_screen.dart';
import '../../features/clients/presentation/client_detail_screen.dart';
import '../../features/clients/presentation/client_list_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/employees/presentation/employee_detail_screen.dart';
import '../../features/employees/presentation/employee_list_screen.dart';
import '../../features/entreprise/presentation/entreprise_profile_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/setup_bureau/presentation/setup_bureau_screen.dart';
import '../../features/setup_bureau/presentation/setup_providers.dart';
import '../../features/superadmin/presentation/superadmin_bootstrap_screen.dart';
import '../../features/superadmin/presentation/superadmin_comptes_screen.dart';
import '../../features/superadmin/presentation/superadmin_entreprise_detail_screen.dart';
import '../../features/superadmin/presentation/superadmin_entreprises_screen.dart';
import '../../features/superadmin/presentation/superadmin_login_screen.dart';
import '../../features/superadmin/presentation/superadmin_parametres_screen.dart';

String _homeForRole(RoleUtilisateur role) => switch (role) {
      RoleUtilisateur.admin => '/admin',
      RoleUtilisateur.manager => '/manager',
      RoleUtilisateur.agent => '/agent',
    };

/// Routes accessibles sans être connecté.
const _publicRoutes = {'/', '/login', '/inscription', '/mot-de-passe-oublie'};

/// Écran de changement de mot de passe obligatoire (compte créé ou
/// réinitialisé par un Admin) — voir la vérification `doitChangerMotDePasse`
/// dans `redirect` ci-dessous.
const _forcePasswordChangeRoute = '/changer-mot-de-passe';

/// Routes du portail Client, accessibles une fois connecté.
const _clientRoutes = {'/client/accueil', '/client/historique', '/client/profil'};
const _clientForcePasswordChangeRoute = '/client/changer-mot-de-passe';

/// Assistant de première connexion bureau (Epic 5f) — n'a de sens que sur le
/// binaire desktop bundlé, jamais sur le web navigateur (voir
/// setupStatutProvider, qui court-circuite sur kIsWeb).
const _setupBureauRoute = '/bureau/connexion-cloud';

/// Fait rejouer les redirections de GoRouter à chaque changement d'état
/// d'authentification (login/logout/expiration de session), staff comme
/// Client, ou de liaison au cloud d'un poste bureau.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen(authControllerProvider, (_, __) => notifyListeners());
    ref.listen(clientAuthControllerProvider, (_, __) => notifyListeners());
    ref.listen(setupStatutProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _AuthRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final location = state.matchedLocation;

      // L'espace super-admin est un principal entièrement séparé, avec sa
      // propre session et son propre token (voir superadmin_auth_controller.dart)
      // — on l'exclut ici avant toute logique staff/client, pour ne pas la
      // faire interférer avec cette arborescence. Chaque écran de
      // `/superadmin/*` gère lui-même sa redirection si non connecté.
      if (location.startsWith('/superadmin')) return null;

      // Poste bureau (Epic 5) pas encore lié à une entreprise cloud : bloque
      // tout accès (y compris /superadmin exclu ci-dessus n'a de toute façon
      // aucun sens sur un poste local) jusqu'à ce que l'assistant de
      // connexion cloud soit complété. Sur le web navigateur, ce provider
      // renvoie toujours `installationTerminee: true` sans appel réseau
      // (voir setupStatutProvider) — ce bloc n'a donc d'effet que sur le
      // binaire desktop bundlé.
      final setupState = ref.read(setupStatutProvider);
      final setupInitialLoading = setupState.isLoading && !setupState.hasValue;
      if (setupInitialLoading) {
        return location == '/splash' ? null : '/splash';
      }
      final setupStatut = setupState.valueOrNull;
      if (setupStatut != null && !setupStatut.installationTerminee) {
        return location == _setupBureauRoute ? null : _setupBureauRoute;
      }

      final authState = ref.read(authControllerProvider);
      final clientAuthState = ref.read(clientAuthControllerProvider);

      // isLoading sans valeur précédente = vérification initiale du token au
      // démarrage. Une action en cours (login/inscription) reste "loading"
      // mais conserve sa valeur précédente via copyWithPrevious : on ne doit
      // surtout pas éjecter l'utilisateur de son formulaire dans ce cas.
      final staffInitialLoading = authState.isLoading && !authState.hasValue;
      final clientInitialLoading = clientAuthState.isLoading && !clientAuthState.hasValue;
      if (staffInitialLoading || clientInitialLoading) {
        return location == '/splash' ? null : '/splash';
      }

      // Identité Client prioritaire si présente : staff et Client partagent
      // le même `tokenStorageProvider` (un seul slot de token par
      // navigateur, voir `client_auth_controller.dart`) — `client_login_screen.dart`
      // et `login_screen.dart` effacent systématiquement l'autre contrôleur
      // après une connexion réussie, donc les deux ne sont jamais valides en
      // même temps en pratique. On tranche quand même explicitement ici pour
      // ne dépendre d'aucun ordre d'exécution.
      final client = clientAuthState.valueOrNull;
      if (client != null) {
        if (client.doitChangerMotDePasse) {
          return location == _clientForcePasswordChangeRoute
              ? null
              : _clientForcePasswordChangeRoute;
        }
        return _clientRoutes.contains(location) ? null : '/client/accueil';
      }

      // Espace Client mais pas (ou plus) de session Client valide : seule la
      // page de connexion Client est accessible, indépendamment d'une
      // éventuelle session staff en parallèle.
      if (location.startsWith('/client')) {
        return location == '/client/login' ? null : '/client/login';
      }

      final user = authState.valueOrNull;
      if (user == null) {
        // Poste bureau (Epic 5) : jamais de page d'accueil publique (site
        // marketing multi-tenant) — contrairement au web, l'app desktop est
        // utilisée par du personnel déjà connu de l'entreprise, exactement
        // comme le mobile. Va directement au login (inscription/mot de passe
        // oublié restent atteignables si on y navigue explicitement).
        if (Env.isDesktopBureau) {
          return location == '/login' ? null : '/login';
        }
        return _publicRoutes.contains(location) ? null : '/';
      }

      // Changement de mot de passe obligatoire (compte fraîchement créé ou
      // réinitialisé) : cette vérification doit primer sur toute autre route
      // authentifiée, y compris `_homeForRole` ci-dessous, sans quoi
      // l'utilisateur pourrait accéder au reste de l'app sans avoir changé
      // son mot de passe temporaire.
      if (user.doitChangerMotDePasse) {
        return location == _forcePasswordChangeRoute ? null : _forcePasswordChangeRoute;
      }
      if (location == _forcePasswordChangeRoute) {
        // Le changement a déjà été effectué (ou le flag est retombé à false
        // autrement) : plus aucune raison de rester sur cet écran.
        return _homeForRole(user.role);
      }

      if (location == '/splash' || _publicRoutes.contains(location)) {
        return _homeForRole(user.role);
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const _SplashScreen()),
      GoRoute(
        path: _setupBureauRoute,
        builder: (context, state) => const SetupBureauScreen(),
      ),
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/inscription', builder: (context, state) => const RegisterScreen()),
      GoRoute(
        path: '/mot-de-passe-oublie',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: _forcePasswordChangeRoute,
        builder: (context, state) => const ForcePasswordChangeScreen(),
      ),
      GoRoute(path: '/admin', builder: (context, state) => const AdminDashboardScreen()),
      GoRoute(
        path: '/admin/employes',
        builder: (context, state) => const EmployeeListScreen(),
      ),
      GoRoute(
        path: '/admin/employes/:employeeId',
        builder: (context, state) =>
            EmployeeDetailScreen(employeeId: state.pathParameters['employeeId']!),
      ),
      GoRoute(
        path: '/admin/clients',
        builder: (context, state) => const AdminClientsScreen(),
      ),
      GoRoute(
        path: '/admin/clients/:clientId',
        builder: (context, state) =>
            ClientDetailScreen(clientId: state.pathParameters['clientId']!),
      ),
      GoRoute(
        path: '/admin/entreprise',
        builder: (context, state) => const EntrepriseProfileScreen(),
      ),
      GoRoute(
        path: '/admin/abonnement',
        builder: (context, state) => const AbonnementScreen(),
      ),
      GoRoute(path: '/manager', builder: (context, state) => const ManagerDashboardScreen()),
      GoRoute(path: '/agent', builder: (context, state) => const ClientListScreen()),
      GoRoute(
        path: '/superadmin/login',
        builder: (context, state) => const SuperAdminLoginScreen(),
      ),
      GoRoute(
        path: '/superadmin/premier-compte',
        builder: (context, state) => const SuperAdminBootstrapScreen(),
      ),
      GoRoute(
        path: '/superadmin',
        builder: (context, state) => const SuperAdminEntreprisesScreen(),
      ),
      GoRoute(
        path: '/superadmin/entreprises/:entrepriseId',
        builder: (context, state) => SuperAdminEntrepriseDetailScreen(
          entrepriseId: state.pathParameters['entrepriseId']!,
        ),
      ),
      GoRoute(
        path: '/superadmin/comptes',
        builder: (context, state) => const SuperAdminComptesScreen(),
      ),
      GoRoute(
        path: '/superadmin/parametres',
        builder: (context, state) => const SuperAdminParametresScreen(),
      ),
      GoRoute(
        path: '/client/login',
        builder: (context, state) => const ClientLoginScreen(),
      ),
      GoRoute(
        path: _clientForcePasswordChangeRoute,
        builder: (context, state) => const ClientForcePasswordChangeScreen(),
      ),
      GoRoute(
        path: '/client/accueil',
        builder: (context, state) => const ClientDashboardScreen(),
      ),
      GoRoute(
        path: '/client/historique',
        builder: (context, state) => const ClientHistoriqueScreen(),
      ),
      GoRoute(
        path: '/client/profil',
        builder: (context, state) => const ClientProfilScreen(),
      ),
    ],
  );
});

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
