import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/offline_queue_service.dart';
import '../../../core/storage/local_db_service.dart';
import '../domain/collecte_result.dart';
import '../domain/retrait_result.dart';
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

  /// Cache-first (Epic 6) — voir `ClientRepository` pour le principe
  /// général. Historique limité aux transactions déjà synchronisées par
  /// `OfflineCacheService` (les 10 dernières pages du registre tenant,
  /// triées par date décroissante — voir `_pagesMaxTransactions`).
  Future<List<Transaction>> listForCompte(String compteId) async {
    final cached = await LocalDbService.instance.getTransactionsForCompte(compteId);
    if (cached.isNotEmpty) return cached;

    final response = await _dio.get('/comptes/$compteId/transactions');
    final transactions = (response.data as List)
        .map((json) => Transaction.fromJson(json as Map<String, dynamic>))
        .toList();
    await LocalDbService.instance.upsertTransactions(transactions);
    return transactions;
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

  /// Activé hors-ligne depuis l'Epic 6 — jusqu'ici exclu (Epic 1) car le
  /// solde n'était pas vérifiable sans réseau. Le solde caché (voir
  /// `CompteRepository.getSolde`) permet désormais une vérification côté
  /// client (`retrait_sheet.dart`, déjà en place) avant l'envoi ; la
  /// validation qui fait foi reste côté serveur au moment de la synchro —
  /// si le solde réel ne suffit plus (ex. deux appareils), l'opération est
  /// retentée puis abandonnée comme n'importe quelle mise en file, jamais
  /// silencieusement perdue (voir `OfflineQueueService.dropped`).
  Future<RetraitResult> createRetrait({
    required String compteId,
    required DateTime date,
    required num montant,
  }) async {
    try {
      final response = await _dio.post(
        '/transactions/retrait',
        data: {
          'compte_id': compteId,
          'date': _formatDate(date),
          'montant': montant,
        },
        options: Options(extra: const {'skipOfflineQueue': true}),
      );
      return RetraitSuccess(Transaction.fromJson(response.data as Map<String, dynamic>));
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) throw MontantRetraitInvalideException();
      if (OfflineQueueService.isConnectivityError(e)) {
        await OfflineQueueService.instance.enqueue(e.requestOptions);
        return RetraitQueued(compteId: compteId, date: date, montant: montant);
      }
      rethrow;
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
