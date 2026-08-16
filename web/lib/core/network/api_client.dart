import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/superadmin/presentation/superadmin_auth_controller.dart';
import '../config/env.dart';
import 'super_admin_token_storage.dart';
import 'token_storage.dart';

final apiClientProvider = Provider<Dio>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await tokenStorage.read();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      // Un 401 en cours de session = jeton expiré (ACCESS_TOKEN_EXPIRE_MINUTES,
      // 60 min par défaut) — sans ça, chaque écran affiche son propre message
      // d'erreur générique ("Impossible de créer le client", "Impossible de
      // charger...") qui masque la vraie cause et laisse l'utilisateur
      // chercher un bug inexistant. On déconnecte directement : le routeur
      // renvoie alors vers /login (voir _AuthRefreshNotifier,
      // app_router.dart). Exclu : /auth/login lui-même, où un 401 signifie
      // "identifiants invalides", pas "session expirée".
      onError: (error, handler) {
        final path = error.requestOptions.path;
        if (error.response?.statusCode == 401 && !path.contains('/auth/login')) {
          ref.read(authControllerProvider.notifier).logout();
        }
        handler.next(error);
      },
    ),
  );

  return dio;
});

/// Client Dio dédié à l'espace super-admin : instance entièrement séparée
/// de [apiClientProvider], avec son propre intercepteur lisant le jeton
/// super-admin. Un jeton super-admin n'est jamais mélangé au jeton
/// staff/client, et vice versa (les deux principaux sont rejetés l'un par
/// l'autre côté backend).
final superAdminApiClientProvider = Provider<Dio>((ref) {
  final tokenStorage = ref.watch(superAdminTokenStorageProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await tokenStorage.read();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        final path = error.requestOptions.path;
        if (error.response?.statusCode == 401 && !path.contains('/auth/superadmin-login')) {
          ref.read(superAdminAuthControllerProvider.notifier).logout();
        }
        handler.next(error);
      },
    ),
  );

  return dio;
});
