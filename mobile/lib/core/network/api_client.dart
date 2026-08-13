import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import 'offline_queue_service.dart';
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
    ),
  );

  dio.interceptors.add(OfflineInterceptor());

  return dio;
});

/// Filet de sécurité générique pour de futures mutations hors-ligne : met en
/// file toute requête POST en échec réseau, sauf si l'appelant l'a déjà
/// prise en charge lui-même (`extra['skipOfflineQueue'] = true` — c'est le
/// cas de `POST /transactions`, géré explicitement par
/// `transaction_repository.dart` pour renvoyer un résultat "en attente"
/// plutôt qu'une simple exception) ou si le chemin est exclu (auth,
/// abonnement — jamais de sens à rejouer une connexion ou une vérification
/// de licence en différé).
class OfflineInterceptor extends Interceptor {
  static const _cheminsExclus = ['/auth', '/abonnement'];

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final dejaGere = options.extra['skipOfflineQueue'] == true;
    final estMutation = options.method.toUpperCase() == 'POST';
    final estExclu = _cheminsExclus.any((p) => options.path.startsWith(p));

    if (!dejaGere &&
        estMutation &&
        !estExclu &&
        OfflineQueueService.isConnectivityError(err)) {
      await OfflineQueueService.instance.enqueue(options);
    }
    handler.next(err);
  }
}
