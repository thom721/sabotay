import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/transaction.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(apiClientProvider));
});

/// Levée quand le backend refuse la collecte avec 402 : abonnement SaaS
/// expiré/non payé (PRD — la collecte de fonds est bloquée tant que
/// l'entreprise n'a pas réglé son abonnement annuel, contrairement à la
/// création de clients/employés qui reste toujours permise).
class SubscriptionRequiredException implements Exception {}

/// Levée quand un retrait dépasse le solde disponible (400 côté backend).
class MontantRetraitInvalideException implements Exception {}

class TransactionRepository {
  final Dio _dio;

  TransactionRepository(this._dio);

  Future<List<Transaction>> listForCompte(int compteId) async {
    final response = await _dio.get('/comptes/$compteId/transactions');
    return (response.data as List)
        .map((json) => Transaction.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Rapport> getRapport({required DateTime dateDebut, required DateTime dateFin}) async {
    final response = await _dio.get('/transactions/rapport', queryParameters: {
      'date_debut': _formatDate(dateDebut),
      'date_fin': _formatDate(dateFin),
    });
    return Rapport.fromJson(response.data as Map<String, dynamic>);
  }

  /// Le montant n'est jamais envoyé — le serveur le calcule toujours comme
  /// nb_jours * montant_journalier du compte, pour qu'il ne soit pas
  /// modifiable même en contournant l'UI.
  Future<Transaction> create({
    required int compteId,
    required DateTime date,
    required int nbJours,
  }) async {
    try {
      final response = await _dio.post('/transactions', data: {
        'compte_id': compteId,
        'date': _formatDate(date),
        'nb_jours': nbJours,
      });
      return Transaction.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 402) throw SubscriptionRequiredException();
      rethrow;
    }
  }

  Future<Transaction> createRetrait({
    required int compteId,
    required DateTime date,
    required num montant,
  }) async {
    try {
      final response = await _dio.post('/transactions/retrait', data: {
        'compte_id': compteId,
        'date': _formatDate(date),
        'montant': montant,
      });
      return Transaction.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) throw MontantRetraitInvalideException();
      rethrow;
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
