import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../abonnement/domain/paiement_abonnement.dart';
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

  Future<List<PaiementAbonnement>> fetchEntreprisePaiements(String id) async {
    final response = await _dio.get('/superadmin/entreprises/$id/paiements');
    return (response.data as List<dynamic>)
        .map((e) => PaiementAbonnement.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Paiements en espèces en attente de confirmation, toutes entreprises
  /// confondues.
  Future<List<PaiementEnAttente>> fetchPaiementsEnAttente() async {
    final response = await _dio.get('/superadmin/paiements-en-attente');
    return (response.data as List<dynamic>)
        .map((e) => PaiementEnAttente.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Confirme un paiement en espèces déclaré par un tenant — active
  /// l'abonnement.
  Future<PaiementAbonnement> confirmerPaiement(String paiementId) async {
    final response = await _dio.post('/superadmin/paiements/$paiementId/confirmer');
    return PaiementAbonnement.fromJson(response.data as Map<String, dynamic>);
  }

  /// Rejette un paiement en espèces déclaré par erreur ou frauduleusement.
  Future<PaiementAbonnement> rejeterPaiement(String paiementId) async {
    final response = await _dio.post('/superadmin/paiements/$paiementId/rejeter');
    return PaiementAbonnement.fromJson(response.data as Map<String, dynamic>);
  }

  /// Repasse `est_installe` à False — l'entreprise pourra refaire
  /// l'installation bureau (un nouveau code d'installation se régénère
  /// automatiquement au prochain accès, voir entreprises.py côté backend).
  Future<EntrepriseSummary> reinitialiserInstallation(String id) async {
    final response =
        await _dio.post('/superadmin/entreprises/$id/reinitialiser-installation');
    return EntrepriseSummary.fromJson(response.data as Map<String, dynamic>);
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
    required int montantRenouvellement,
    required int essaiJours,
  }) async {
    final response = await _dio.patch(
      '/superadmin/config',
      data: {
        'abonnement_montant_htg': montant,
        'abonnement_renouvellement_htg': montantRenouvellement,
        'essai_jours': essaiJours,
      },
    );
    return PlatformConfig.fromJson(response.data as Map<String, dynamic>);
  }

  /// PATCH partiel côté backend (voir PlatformConfigUpdate) — seuls les
  /// champs fournis ici sont modifiés, l'onglet Abonnement n'est jamais
  /// touché par un enregistrement de l'onglet Email, et vice versa.
  /// `smtpPassword` omis (null) = mot de passe existant conservé tel quel.
  Future<PlatformConfig> updatePlatformConfigEmail({
    required String smtpHost,
    required int smtpPort,
    required String smtpUser,
    String? smtpPassword,
    required String smtpFromEmail,
  }) async {
    final response = await _dio.patch(
      '/superadmin/config',
      data: {
        'smtp_host': smtpHost,
        'smtp_port': smtpPort,
        'smtp_user': smtpUser,
        if (smtpPassword != null && smtpPassword.isNotEmpty) 'smtp_password': smtpPassword,
        'smtp_from_email': smtpFromEmail,
      },
    );
    return PlatformConfig.fromJson(response.data as Map<String, dynamic>);
  }
}
