import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/abonnement.dart';
import '../domain/paiement_abonnement.dart';

final abonnementRepositoryProvider = Provider<AbonnementRepository>((ref) {
  return AbonnementRepository(ref.watch(apiClientProvider));
});

/// Abonnement de l'entreprise (statut, plan, échéances) — accessible en
/// lecture à tout le staff authentifié.
final abonnementProvider = FutureProvider<Abonnement>((ref) {
  return ref.watch(abonnementRepositoryProvider).getAbonnement();
});

/// Historique des paiements de l'entreprise, du plus récent au plus ancien.
final paiementsAbonnementProvider = FutureProvider<List<PaiementAbonnement>>((ref) {
  return ref.watch(abonnementRepositoryProvider).getPaiements();
});

class AbonnementRepository {
  final Dio _dio;

  AbonnementRepository(this._dio);

  Future<Abonnement> getAbonnement() async {
    final response = await _dio.get('/abonnement');
    return Abonnement.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<PaiementAbonnement>> getPaiements() async {
    final response = await _dio.get('/abonnement/paiements');
    return (response.data as List<dynamic>)
        .map((e) => PaiementAbonnement.fromJson(e as Map<String, dynamic>))
        .toList();
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

  /// Déclare un paiement en espèces (Admin uniquement) — reste en_attente
  /// jusqu'à confirmation par un superadmin, n'active pas l'abonnement.
  Future<PaiementAbonnement> declarerPaiementEspeces() async {
    final response = await _dio.post('/abonnement/declarer-especes', data: {});
    return PaiementAbonnement.fromJson(response.data as Map<String, dynamic>);
  }
}
