import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/abonnement.dart';

final abonnementRepositoryProvider = Provider<AbonnementRepository>((ref) {
  return AbonnementRepository(ref.watch(apiClientProvider));
});

/// Abonnement de l'entreprise (statut, plan, échéances) — accessible en
/// lecture à tout le staff authentifié.
final abonnementProvider = FutureProvider<Abonnement>((ref) {
  return ref.watch(abonnementRepositoryProvider).getAbonnement();
});

class AbonnementRepository {
  final Dio _dio;

  AbonnementRepository(this._dio);

  Future<Abonnement> getAbonnement() async {
    final response = await _dio.get('/abonnement');
    return Abonnement.fromJson(response.data as Map<String, dynamic>);
  }

  /// Démarre un paiement MonCash (Admin uniquement) et renvoie l'URL de
  /// paiement hébergée vers laquelle rediriger le navigateur. Lève une
  /// [DioException] (statusCode 503 tant que les identifiants marchands
  /// MonCash réels ne sont pas configurés) que l'appelant peut distinguer.
  Future<String> payer() async {
    final response = await _dio.post('/abonnement/payer', data: {});
    final data = response.data as Map<String, dynamic>;
    return data['redirect_url'] as String;
  }

  /// Vérifie auprès de MonCash si le paiement a bien été reçu (Admin
  /// uniquement). Renvoie `paye` (le paiement a-t-il été confirmé lors de
  /// cet appel) ainsi que l'abonnement à jour.
  Future<({bool paye, Abonnement abonnement})> verifier() async {
    final response = await _dio.post('/abonnement/verifier', data: {});
    final data = response.data as Map<String, dynamic>;
    return (
      paye: data['paye'] as bool,
      abonnement: Abonnement.fromJson(data['abonnement'] as Map<String, dynamic>),
    );
  }
}
