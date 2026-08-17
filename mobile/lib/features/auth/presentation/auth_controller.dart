import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/licence/licence_verifier.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/offline_queue_service.dart';
import '../../../core/network/token_storage.dart';
import '../../clients/presentation/client_list_controller.dart';
import '../../entreprise/presentation/entreprise_providers.dart';
import '../data/auth_repository.dart';
import '../domain/user.dart';

final authControllerProvider =
    AsyncNotifierProvider<AuthController, User?>(AuthController.new);

/// Levée par [AuthController.login] quand un agent d'une autre entreprise
/// tente de se connecter alors que des opérations de l'agent précédent sont
/// encore en attente d'envoi — trop risqué de les vider silencieusement
/// (perte réelle d'une collecte jamais transmise), donc on bloque plutôt que
/// de nettoyer. Le message est présenté tel quel (voir `login_screen.dart`).
class SyncEnAttenteException implements Exception {
  final String message;
  const SyncEnAttenteException(this.message);

  @override
  String toString() => message;
}

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
    // Capturés avant d'écraser l'état/le token — nécessaires pour détecter
    // un changement d'entreprise juste en dessous, et pour pouvoir revenir
    // en arrière si la connexion doit être bloquée.
    final utilisateurPrecedent = state.valueOrNull;
    final tokenStorage = ref.read(tokenStorageProvider);
    final ancienToken = await tokenStorage.read();

    // Tenté AVANT de changer de session, tant que l'ancien token est encore
    // actif : si un changement d'entreprise suit, une file déjà vide n'aura
    // rien à bloquer. Meilleur effort — reste en file si hors-ligne, géré
    // juste en dessous.
    if (utilisateurPrecedent != null &&
        await OfflineQueueService.instance.pendingCount() > 0) {
      await OfflineQueueService.instance.drain(ref.read(apiClientProvider));
    }

    // copyWithPrevious évite que le routeur n'éjecte l'utilisateur de son
    // formulaire pendant la soumission (voir même pattern côté web).
    state = const AsyncLoading<User?>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final repository = ref.read(authRepositoryProvider);
      final token = await repository.login(identifiant: identifiant, password: password);
      await tokenStorage.save(token);
      final nouvelUtilisateur = await repository.fetchCurrentUser();

      if (utilisateurPrecedent != null &&
          utilisateurPrecedent.entrepriseId != nouvelUtilisateur.entrepriseId) {
        final enAttente = await OfflineQueueService.instance.pendingCount();
        if (enAttente > 0) {
          // Trop risqué de vider silencieusement (perte réelle d'une
          // collecte jamais transmise) — on bloque plutôt : restaure
          // l'ancien token pour que l'agent précédent reste connecté et
          // puisse synchroniser dès qu'il retrouve le réseau, et fait
          // échouer cette connexion avec un message explicite.
          if (ancienToken != null) {
            await tokenStorage.save(ancienToken);
          } else {
            await tokenStorage.clear();
          }
          throw SyncEnAttenteException(
            enAttente == 1
                ? 'Une opération de l\'agent précédent est encore en attente d\'envoi. '
                    'Reconnectez-vous au réseau pour la synchroniser avant de changer de compte.'
                : '$enAttente opérations de l\'agent précédent sont encore en attente '
                    'd\'envoi. Reconnectez-vous au réseau pour les synchroniser avant de '
                    'changer de compte.',
          );
        }

        // File vide (déjà à jour, ou vidée par le drain ci-dessus) : les
        // providers scoped-entreprise gardent sinon en mémoire les données
        // du compte précédent (profil entreprise sur les reçus, liste de
        // clients) jusqu'à un rafraîchissement manuel. Même principe que
        // `ClientAuthController.switchEntreprise`, jamais répliqué ici.
        ref.invalidate(entrepriseProfilProvider);
        ref.invalidate(clientListControllerProvider);
      }

      return nouvelUtilisateur;
    });
  }

  Future<void> refreshCurrentUser() async {
    state = const AsyncLoading<User?>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => ref.read(authRepositoryProvider).fetchCurrentUser());
  }

  Future<void> logout() async {
    await ref.read(tokenStorageProvider).clear();
    await LicenceVerifier.clearCache();
    state = const AsyncData(null);
  }

  /// Appelé quand l'identité Client vient de se connecter sur le même
  /// appareil — le token Utilisateur (s'il y en avait un) est déjà
  /// remplacé, on ne fait qu'oublier l'état en mémoire.
  void clearSilently() {
    state = const AsyncData(null);
  }
}
