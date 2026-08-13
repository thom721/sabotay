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

  Future<List<CompteSabotay>> listForClient(String clientId) async {
    final response = await _dio.get('/clients/$clientId/comptes');
    return (response.data as List)
        .map((json) => CompteSabotay.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<CompteSabotay> create({
    required String clientId,
    required num montantJournalier,
    required DateTime dateDebut,
    required int dureeJours,
  }) async {
    final response = await _dio.post(
      '/comptes',
      data: {
        'client_id': clientId,
        'montant_journalier': montantJournalier,
        'date_debut': dateDebut.toIso8601String().split('T').first,
        'duree_jours': dureeJours,
      },
    );
    return CompteSabotay.fromJson(response.data as Map<String, dynamic>);
  }

  Future<CompteSolde> getSolde(String compteId) async {
    final response = await _dio.get('/comptes/$compteId/solde');
    return CompteSolde.fromJson(response.data as Map<String, dynamic>);
  }
}
