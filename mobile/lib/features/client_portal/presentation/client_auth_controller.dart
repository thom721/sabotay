import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/token_storage.dart';
import '../data/client_auth_repository.dart';
import '../data/client_entreprise_repository.dart';
import '../domain/client_principal.dart';
import 'client_compte_providers.dart';
import 'client_entreprise_providers.dart';

final clientAuthControllerProvider =
    AsyncNotifierProvider<ClientAuthController, ClientPrincipal?>(ClientAuthController.new);

/// Même forme que `AuthController` (`features/auth/presentation/auth_controller.dart`)
/// mais pour l'identité Client — un appareil ne sert qu'une personne à la
/// fois, les deux contrôleurs partagent donc le même `tokenStorageProvider`
/// (un seul slot de token). `login_screen.dart` est responsable de
/// réinitialiser l'autre identité après une connexion réussie, pour éviter
/// qu'un ancien état Utilisateur/Client ne reste en cache.
class ClientAuthController extends AsyncNotifier<ClientPrincipal?> {
  @override
  Future<ClientPrincipal?> build() async {
    final token = await ref.watch(tokenStorageProvider).read();
    if (token == null) return null;

    try {
      return await ref.watch(clientAuthRepositoryProvider).fetchMe();
    } on DioException {
      return null;
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncLoading<ClientPrincipal?>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final repository = ref.read(clientAuthRepositoryProvider);
      final token = await repository.login(email: email, password: password);
      await ref.read(tokenStorageProvider).save(token);
      return repository.fetchMe();
    });
  }

  /// Change d'entreprise sans repasser par le mot de passe : `switchEntreprise`
  /// n'accepte que les `client_id` liés au même email que l'identité déjà
  /// authentifiée (vérifié côté backend), ce qui permet de réutiliser le
  /// même flux que `login` (nouveau token → sauvegarde → `fetchMe`).
  Future<void> switchEntreprise(String clientId) async {
    state = const AsyncLoading<ClientPrincipal?>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final entrepriseRepository = ref.read(clientEntrepriseRepositoryProvider);
      final authRepository = ref.read(clientAuthRepositoryProvider);
      final token = await entrepriseRepository.switchEntreprise(clientId);
      await ref.read(tokenStorageProvider).save(token);
      ref.invalidate(clientMesComptesProvider);
      ref.invalidate(clientCompteSelectionneProvider);
      ref.invalidate(clientEntreprisesLieesProvider);
      ref.invalidate(clientEntrepriseProfilProvider);
      return authRepository.fetchMe();
    });
  }

  Future<void> refreshCurrentClient() async {
    state = const AsyncLoading<ClientPrincipal?>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => ref.read(clientAuthRepositoryProvider).fetchMe());
  }

  Future<void> logout() async {
    await ref.read(tokenStorageProvider).clear();
    state = const AsyncData(null);
  }

  /// Appelé quand l'identité Utilisateur vient de se connecter sur le même
  /// appareil — le token du Client (s'il y en avait un) est déjà remplacé,
  /// on ne fait qu'oublier l'état en mémoire, sans re-toucher au token.
  void clearSilently() {
    state = const AsyncData(null);
  }
}
