import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/transaction.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(apiClientProvider));
});

class TransactionRepository {
  final Dio _dio;

  TransactionRepository(this._dio);

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// [agentId] filtre les collectes/retraits d'un agent précis — ignoré côté
  /// backend si l'appelant est lui-même un Agent (toujours forcé sur ses
  /// propres transactions), utile seulement pour Admin/Manager.
  Future<Rapport> getRapport({
    required DateTime dateDebut,
    required DateTime dateFin,
    String? agentId,
  }) async {
    final response = await _dio.get(
      '/transactions/rapport',
      queryParameters: {
        'date_debut': _isoDate(dateDebut),
        'date_fin': _isoDate(dateFin),
        if (agentId != null) 'agent_id': agentId,
      },
    );
    return Rapport.fromJson(response.data as Map<String, dynamic>);
  }

  /// Registre paginé, recherche libre par client/compte/agent — pour
  /// retrouver une transaction précise (contrairement à [getRapport], borné
  /// à une période et pensé pour la synthèse).
  Future<RegistrePage> getRegistre({
    String? q,
    int skip = 0,
    int limit = 50,
  }) async {
    final response = await _dio.get(
      '/transactions',
      queryParameters: {
        if (q != null && q.isNotEmpty) 'q': q,
        'skip': skip,
        'limit': limit,
      },
    );
    return RegistrePage.fromJson(response.data as Map<String, dynamic>);
  }
}
