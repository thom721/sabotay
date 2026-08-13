import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/entreprise_detail.dart';
import '../domain/entreprise_summary.dart';
import '../domain/platform_config.dart';
import '../domain/platform_statistiques.dart';
import '../domain/superadmin_compte.dart';

final superAdminRepositoryProvider = Provider<SuperAdminRepository>((ref) {
  return SuperAdminRepository(ref.watch(superAdminApiClientProvider));
});

class SuperAdminRepository {
  final Dio _dio;

  SuperAdminRepository(this._dio);

  Future<List<EntrepriseSummary>> fetchEntreprises({String? q, String? statutAbonnement}) async {
    final response = await _dio.get(
      '/superadmin/entreprises',
      queryParameters: {
        if (q != null && q.isNotEmpty) 'q': q,
        if (statutAbonnement != null && statutAbonnement.isNotEmpty)
          'statut_abonnement': statutAbonnement,
      },
    );
    return (response.data as List<dynamic>)
        .map((e) => EntrepriseSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<EntrepriseDetail> fetchEntrepriseDetail(String id) async {
    final response = await _dio.get('/superadmin/entreprises/$id');
    return EntrepriseDetail.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PlatformStatistiques> getStatistiques() async {
    final response = await _dio.get('/superadmin/statistiques');
    return PlatformStatistiques.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<SuperAdminCompte>> fetchComptes() async {
    final response = await _dio.get('/superadmin/comptes');
    return (response.data as List<dynamic>)
        .map((e) => SuperAdminCompte.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SuperAdminCompte> createCompte({
    required String nom,
    required String email,
    required String password,
  }) async {
    final response = await _dio.post(
      '/superadmin/comptes',
      data: {'nom': nom, 'email': email, 'password': password},
    );
    return SuperAdminCompte.fromJson(response.data as Map<String, dynamic>);
  }

  Future<SuperAdminCompte> updateCompteStatut(String id, String statut) async {
    final response = await _dio.patch(
      '/superadmin/comptes/$id/statut',
      data: {'statut': statut},
    );
    return SuperAdminCompte.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PlatformConfig> getPlatformConfig() async {
    final response = await _dio.get('/superadmin/config');
    return PlatformConfig.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PlatformConfig> updatePlatformConfig({
    required int montant,
    required int essaiJours,
  }) async {
    final response = await _dio.patch(
      '/superadmin/config',
      data: {'abonnement_montant_htg': montant, 'essai_jours': essaiJours},
    );
    return PlatformConfig.fromJson(response.data as Map<String, dynamic>);
  }
}
