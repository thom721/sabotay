import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/local_db_service.dart';
import '../domain/compte_sabotay.dart';

final compteRepositoryProvider = Provider<CompteRepository>((ref) {
  return CompteRepository(ref.watch(apiClientProvider));
});

/// Cache-first (Epic 6) — voir `ClientRepository` pour le principe général.
/// Le solde vient du même cache que le compte (une seule table, peuplée par
/// `OfflineCacheService._syncComptes` via `GET /comptes`, solde calculé en
/// masse côté serveur) : plus besoin d'un aller-retour réseau séparé par
/// compte une fois le cache chaud.
class CompteRepository {
  final Dio _dio;

  CompteRepository(this._dio);

  Future<List<CompteSabotay>> listForClient(String clientId) async {
    final cached = await LocalDbService.instance.getComptesForClient(clientId);
    if (cached.isNotEmpty) return cached;

    final response = await _dio.get('/clients/$clientId/comptes');
    final comptes = (response.data as List)
        .map((json) => CompteSabotay.fromJson(json as Map<String, dynamic>))
        .toList();
    // Pas de solde disponible depuis cet endpoint (comptes bruts, sans
    // agrégat) — le cache ne sera complété avec le solde qu'au prochain
    // cycle `OfflineCacheService.syncAll` (GET /comptes). Un `getSolde()`
    // appelé juste après ce repli réseau retombera donc lui aussi sur le
    // réseau, correct mais pas optimal — cas rare (uniquement avant le tout
    // premier sync réussi).
    return comptes;
  }

  Future<CompteSolde> getSolde(String compteId) async {
    final cached = await LocalDbService.instance.getSolde(compteId);
    if (cached != null) return cached;

    final response = await _dio.get('/comptes/$compteId/solde');
    return CompteSolde.fromJson(response.data as Map<String, dynamic>);
  }

  /// Sert la collecte rapide par numéro de compte (bouton + flottant de la
  /// page d'accueil), accessible aux 3 rôles côté backend.
  Future<CompteSabotay?> getByNumero(String numeroCompte) async {
    final cached = await LocalDbService.instance.getCompteParNumero(numeroCompte);
    if (cached != null) return cached;

    try {
      final response = await _dio.get('/comptes/numero/$numeroCompte');
      return CompteSabotay.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}
