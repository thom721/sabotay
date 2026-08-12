import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/accueil/presentation/accueil_screen.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/force_password_change_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/client_portal/presentation/client_auth_controller.dart';
import '../../features/client_portal/presentation/client_dashboard_screen.dart';
import '../../features/client_portal/presentation/client_force_password_change_screen.dart';
import '../../features/client_portal/presentation/client_historique_screen.dart';
import '../../features/client_portal/presentation/client_profil_screen.dart';
import '../../features/clients/presentation/client_list_screen.dart';

/// Routage mobile, volontairement plus simple que le web : pas de vitrine
/// publique, pas d'inscription, pas de mot de passe oublié (PRD §5.3) — la
/// seule route non authentifiée est /login. Deux identités distinctes
/// peuvent être connectées : Utilisateur (Admin/Manager/Agent, un seul
/// accueil partagé) et Client (portail libre-service) — un appareil ne sert
/// qu'une personne à la fois (`login_screen.dart` réinitialise l'autre
/// identité à la connexion), donc la priorité Client > Utilisateur > /login
/// suffit à trancher sans ambiguïté.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      // Lire l'état à chaque appel plutôt que de le `watch` au niveau du
      // provider : `_AuthListenable` se charge déjà de redéclencher cette
      // fonction à chaque changement — un `watch` ici recréerait tout le
      // GoRouter (qui repart alors de `initialLocation: '/login'`) à chaque
      // changement d'identité Client, provoquant un flash visible par l'écran
      // de connexion (ex. lors d'un changement d'entreprise).
      final authState = ref.read(authControllerProvider);
      final clientAuthState = ref.read(clientAuthControllerProvider);
      final location = state.matchedLocation;

      if (authState.isLoading || clientAuthState.isLoading) return null;

      final client = clientAuthState.valueOrNull;
      if (client != null) {
        if (client.doitChangerMotDePasse) {
          return location == '/client/changer-mot-de-passe'
              ? null
              : '/client/changer-mot-de-passe';
        }
        final clientRoutes = {
          '/client/accueil',
          '/client/historique',
          '/client/profil',
        };
        return clientRoutes.contains(location) ? null : '/client/accueil';
      }

      final user = authState.valueOrNull;
      if (user == null) {
        return location == '/login' ? null : '/login';
      }

      // Priorité absolue : mot de passe temporaire non changé — bloque
      // l'accès à tout le reste tant que ce n'est pas fait.
      if (user.doitChangerMotDePasse) {
        return location == '/changer-mot-de-passe' ? null : '/changer-mot-de-passe';
      }

      // Un seul accueil pour les trois rôles Utilisateur (Admin/Manager/
      // Agent) : la grille de raccourcis. Ce qui distingue qui a collecté
      // se voit sur le reçu (collecte_par_nom), pas sur un écran séparé.
      if (location == '/login' || location == '/changer-mot-de-passe') {
        return '/accueil';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/changer-mot-de-passe',
        builder: (context, state) => const ForcePasswordChangeScreen(),
      ),
      GoRoute(path: '/accueil', builder: (context, state) => const AccueilScreen()),
      GoRoute(path: '/clients', builder: (context, state) => const ClientListScreen()),
      GoRoute(
        path: '/client/changer-mot-de-passe',
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

/// Pont entre les AsyncNotifier de Riverpod et le Listenable attendu par
/// go_router pour redéclencher `redirect` à chaque changement d'état
/// d'authentification, Utilisateur ou Client.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(this._ref) {
    _ref.listen(authControllerProvider, (_, __) => notifyListeners());
    _ref.listen(clientAuthControllerProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;
}
