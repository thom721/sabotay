import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../comptes/domain/compte_sabotay.dart';
import '../../transactions/domain/transaction.dart';

final clientCompteRepositoryProvider = Provider<ClientCompteRepository>((ref) {
  return ClientCompteRepository(ref.watch(apiClientProvider));
});

/// Comptes du Client connecté — lecture seule (PRD §8.8), scopés côté
/// backend via `CurrentClient` + vérification de propriété
/// (`crud_compte_sabotay.get_for_client`).
class ClientCompteRepository {
  final Dio _dio;

  ClientCompteRepository(this._dio);

  Future<List<CompteSabotay>> listMesComptes() async {
    final response = await _dio.get('/clients/moi/comptes');
    return (response.data as List)
        .map((json) => CompteSabotay.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<CompteSolde> getSolde(String compteId) async {
    final response = await _dio.get('/clients/moi/comptes/$compteId/solde');
    return CompteSolde.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<Transaction>> getTransactions(String compteId) async {
    final response = await _dio.get('/clients/moi/comptes/$compteId/transactions');
    return (response.data as List)
        .map((json) => Transaction.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
