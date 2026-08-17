import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/transaction.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(apiClientProvider));
});

/// Levée quand le backend refuse la collecte avec 402 : abonnement SaaS
/// expiré/non payé (même garde-fou que côté mobile).
class SubscriptionRequiredException implements Exception {}

/// Levée quand un retrait dépasse le solde disponible (400 côté backend).
class MontantRetraitInvalideException implements Exception {}

class TransactionRepository {
  final Dio _dio;

  TransactionRepository(this._dio);

  /// Le montant n'est jamais envoyé — le serveur le calcule toujours comme
  /// nb_jours * montant_journalier du compte (même contrat que le mobile,
  /// voir mobile/lib/features/transactions/data/transaction_repository.dart
  /// — pas de file d'attente hors-ligne ici, le poste bureau parle toujours
  /// à son propre serveur local).
  Future<Transaction> createCollecte({
    required String compteId,
    required DateTime date,
    required int nbJours,
  }) async {
    try {
      final response = await _dio.post(
        '/transactions',
        data: {'compte_id': compteId, 'date': _isoDate(date), 'nb_jours': nbJours},
      );
      return Transaction.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 402) throw SubscriptionRequiredException();
      rethrow;
    }
  }

  /// Retrait partiel plafonné au solde disponible — validation faisant foi
  /// côté serveur, voir [MontantRetraitInvalideException].
  Future<Transaction> createRetrait({
    required String compteId,
    required DateTime date,
    required num montant,
  }) async {
    try {
      final response = await _dio.post(
        '/transactions/retrait',
        data: {'compte_id': compteId, 'date': _isoDate(date), 'montant': montant},
      );
      return Transaction.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) throw MontantRetraitInvalideException();
      rethrow;
    }
  }

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
