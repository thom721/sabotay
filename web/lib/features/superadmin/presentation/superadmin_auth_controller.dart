import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import '../../../core/config/env.dart';
import '../../../core/network/super_admin_token_storage.dart';
import '../data/superadmin_auth_repository.dart';

/// État minimal : `true` si un jeton super-admin valide (présent) est
/// stocké, `false` sinon. Il n'existe pas d'endpoint `/superadmin/me` — on
/// ne connaît donc pas de profil, seulement la présence d'un jeton. Ce
/// contrôleur est entièrement indépendant de l'`AuthController` staff : les
/// deux sessions ne se lisent, ni ne s'écrivent l'une l'autre.
final superAdminAuthControllerProvider =
    AsyncNotifierProvider<SuperAdminAuthController, bool>(SuperAdminAuthController.new);

class SuperAdminAuthController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final token = await ref.watch(superAdminTokenStorageProvider).read();
    return token != null;
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncLoading<bool>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final repository = ref.read(superAdminAuthRepositoryProvider);
      final token = await repository.login(email: email, password: password);
      await ref.read(superAdminTokenStorageProvider).save(token);
      return true;
    });
  }

  /// Crée le tout premier compte super-admin puis connecte directement —
  /// même principe que `AuthController.registerEntreprise` (staff) : un seul
  /// appel côté écran, la connexion s'enchaîne automatiquement après la
  /// création.
  Future<void> bootstrapPremierCompte({
    required String nom,
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading<bool>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final repository = ref.read(superAdminAuthRepositoryProvider);
      await repository.bootstrap(nom: nom, email: email, password: password);
      final token = await repository.login(email: email, password: password);
      await ref.read(superAdminTokenStorageProvider).save(token);
      return true;
    });
  }

  Future<void> logout() async {
    await ref.read(superAdminTokenStorageProvider).clear();
    state = const AsyncData(false);
  }
}

/// Vrai uniquement tant qu'aucun compte super-admin n'existe — consulté par
/// [SuperAdminLoginScreen] pour proposer l'écran de création du tout
/// premier compte au lieu de l'écran de connexion habituel.
///
/// Réservé au web (cloud) — toujours `false` sur le binaire desktop bundlé :
/// la base SQLite d'un poste bureau n'a jamais de `super_admins` (données de
/// plateforme, jamais synchronisées vers le local, voir ENTITES dans
/// sync.py), donc ce provider y répondrait toujours `true` sans ce
/// court-circuit — proposant de créer un "super-admin" local fantôme, sans
/// aucun sens sur une installation mono-tenant.
final superAdminBootstrapNecessaireProvider = FutureProvider<bool>((ref) {
  if (Env.isDesktopBureau) return false;
  return ref.watch(superAdminAuthRepositoryProvider).bootstrapNecessaire();
});

/// Id du compte super-admin actuellement connecté, obtenu en décodant
/// localement le claim `sub` du jeton — il n'existe pas d'endpoint
/// `/superadmin/me`. Utilisé uniquement pour les gardes UI d'auto-protection
/// (ex. désactiver son propre compte) ; le backend reste la source de
/// vérité et rejette de toute façon l'action côté serveur.
final superAdminSelfIdProvider = FutureProvider<String?>((ref) async {
  final token = await ref.watch(superAdminTokenStorageProvider).read();
  if (token == null) return null;
  try {
    final claims = JwtDecoder.decode(token);
    final sub = claims['sub'];
    return sub as String?;
  } catch (_) {
    return null;
  }
});
