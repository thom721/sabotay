import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/compte_sabotay.dart';

final compteRepositoryProvider = Provider<CompteRepository>((ref) {
  return CompteRepository(ref.watch(apiClientProvider));
});

class CompteRepository {
  final Dio _dio;

  CompteRepository(this._dio);

  Future<List<CompteSabotay>> listForClient(int clientId) async {
    final response = await _dio.get('/clients/$clientId/comptes');
    return (response.data as List)
        .map((json) => CompteSabotay.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<CompteSolde> getSolde(int compteId) async {
    final response = await _dio.get('/comptes/$compteId/solde');
    return CompteSolde.fromJson(response.data as Map<String, dynamic>);
  }

  /// Sert la collecte rapide par numéro de compte (bouton + flottant de la
  /// page d'accueil), accessible aux 3 rôles côté backend.
  Future<CompteSabotay?> getByNumero(String numeroCompte) async {
    try {
      final response = await _dio.get('/comptes/numero/$numeroCompte');
      return CompteSabotay.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}
