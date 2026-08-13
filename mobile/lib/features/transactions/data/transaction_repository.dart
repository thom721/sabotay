import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/offline_queue_service.dart';
import '../domain/collecte_result.dart';
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

  Future<List<Transaction>> listForCompte(String compteId) async {
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
  /// modifiable même en contournant l'UI. `montant` ici ne sert qu'à
  /// peupler un [CollecteQueued] provisoire si la requête ne peut pas
  /// atteindre le serveur — jamais envoyé dans la requête elle-même.
  ///
  /// `extra: {'skipOfflineQueue': true}` : cette méthode gère elle-même la
  /// mise en file (pour renvoyer [CollecteQueued] plutôt qu'une exception
  /// nue) — l'intercepteur générique [OfflineInterceptor] ne doit pas la
  /// traiter une deuxième fois.
  Future<CollecteResult> create({
    required String compteId,
    required DateTime date,
    required int nbJours,
    required num montant,
  }) async {
    try {
      final response = await _dio.post(
        '/transactions',
        data: {
          'compte_id': compteId,
          'date': _formatDate(date),
          'nb_jours': nbJours,
        },
        options: Options(extra: const {'skipOfflineQueue': true}),
      );
      return CollecteSuccess(Transaction.fromJson(response.data as Map<String, dynamic>));
    } on DioException catch (e) {
      if (e.response?.statusCode == 402) throw SubscriptionRequiredException();
      if (OfflineQueueService.isConnectivityError(e)) {
        await OfflineQueueService.instance.enqueue(e.requestOptions);
        return CollecteQueued(compteId: compteId, date: date, nbJours: nbJours, montant: montant);
      }
      rethrow;
    }
  }

  Future<Transaction> createRetrait({
    required String compteId,
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
