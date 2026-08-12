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
      // Ne pas effacer le token ici : depuis le portail Client, le même
      // slot de token peut légitimement contenir un token Client, que
      // /auth/me rejette (type claim) sans que le token soit invalide.
      return null;
    }
  }

  Future<void> login({required String identifiant, required String password}) async {
    // copyWithPrevious évite que le routeur n'éjecte l'utilisateur de son
    // formulaire pendant la soumission (voir même pattern côté web).
    state = const AsyncLoading<User?>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final repository = ref.read(authRepositoryProvider);
      final token = await repository.login(identifiant: identifiant, password: password);
      await ref.read(tokenStorageProvider).save(token);
      return repository.fetchCurrentUser();
    });
  }

  Future<void> refreshCurrentUser() async {
    state = const AsyncLoading<User?>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => ref.read(authRepositoryProvider).fetchCurrentUser());
  }

  Future<void> logout() async {
    await ref.read(tokenStorageProvider).clear();
    state = const AsyncData(null);
  }

  /// Appelé quand l'identité Client vient de se connecter sur le même
  /// appareil — le token Utilisateur (s'il y en avait un) est déjà
  /// remplacé, on ne fait qu'oublier l'état en mémoire.
  void clearSilently() {
    state = const AsyncData(null);
  }
}
