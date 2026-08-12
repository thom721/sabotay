import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/token_storage.dart';
import '../data/auth_repository.dart';
import '../domain/user.dart';

final authControllerProvider =
    AsyncNotifierProvider<AuthController, User?>(AuthController.new);

class AuthController extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    final token = await ref.watch(tokenStorageProvider).read();
    if (token == null) return null;

    try {
      return await ref.watch(authRepositoryProvider).fetchCurrentUser();
    } on DioException {
      // Token invalide ou expiré : on repart d'un état déconnecté.
      await ref.watch(tokenStorageProvider).clear();
      return null;
    }
  }

  Future<void> login({required String identifiant, required String password}) async {
    // copyWithPrevious garde la valeur précédente accessible pendant le
    // chargement : le router ne doit pas éjecter l'utilisateur vers l'écran
    // de démarrage pendant qu'il soumet le formulaire de connexion.
    state = const AsyncLoading<User?>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => _loginAndFetchUser(identifiant, password));
  }

  /// Inscrit l'entreprise + son Admin puis connecte directement ce dernier
  /// (PRD §7.1 : le formulaire d'inscription enchaîne sur l'espace tenant).
  Future<void> registerEntreprise({
    required String nomEntreprise,
    required String devise,
    required String adminNom,
    required String adminTelephone,
    String? adminEmail,
    required String adminPassword,
  }) async {
    state = const AsyncLoading<User?>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final repository = ref.read(authRepositoryProvider);
      await repository.registerEntreprise(
        nomEntreprise: nomEntreprise,
        devise: devise,
        adminNom: adminNom,
        adminTelephone: adminTelephone,
        adminEmail: adminEmail,
        adminPassword: adminPassword,
      );
      return _loginAndFetchUser(adminTelephone, adminPassword);
    });
  }

  Future<User?> _loginAndFetchUser(String identifiant, String password) async {
    final repository = ref.read(authRepositoryProvider);
    final token = await repository.login(identifiant: identifiant, password: password);
    await ref.read(tokenStorageProvider).save(token);
    return repository.fetchCurrentUser();
  }

  Future<void> logout() async {
    await ref.read(tokenStorageProvider).clear();
    state = const AsyncData(null);
  }

  /// Appelé quand l'identité Client vient de se connecter avec succès sur le
  /// même navigateur — le token staff (s'il y en avait un) est déjà remplacé
  /// par `ClientAuthController.login`, on ne fait qu'oublier l'état en
  /// mémoire, sans re-toucher au token.
  void clearSilently() {
    state = const AsyncData(null);
  }

  /// Recharge l'utilisateur courant depuis `/auth/me` sans repasser par
  /// l'état "loading" (évite d'éjecter l'utilisateur pendant le rafraîchissement,
  /// par ex. juste après un changement de mot de passe forcé). Utilisé pour
  /// que `doit_changer_mot_de_passe` reflète bien le serveur après coup.
  Future<void> refreshCurrentUser() async {
    final repository = ref.read(authRepositoryProvider);
    state = await AsyncValue.guard(() => repository.fetchCurrentUser());
  }
}
