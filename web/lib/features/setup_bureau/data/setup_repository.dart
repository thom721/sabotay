import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/setup_statut.dart';

final setupRepositoryProvider = Provider<SetupRepository>((ref) {
  return SetupRepository(ref.watch(apiClientProvider));
});

class SetupRepository {
  final Dio _dio;

  SetupRepository(this._dio);

  /// `/setup/*` n'exige aucune authentification côté backend (voir
  /// setup.py) — un poste local fraîchement installé n'a encore aucun
  /// utilisateur pour se connecter. [apiClientProvider] n'ajoute
  /// l'en-tête Authorization que si un jeton existe déjà, donc aucun
  /// client Dio séparé n'est nécessaire ici.
  Future<SetupStatut> fetchStatut() async {
    final response = await _dio.get('/setup/statut');
    return SetupStatut.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> connecter({required String code, required String cloudUrl}) async {
    await _dio.post('/setup/connecter', data: {
      'code': code,
      'cloud_url': cloudUrl,
    });
  }
}
