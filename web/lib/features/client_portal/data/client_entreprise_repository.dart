import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../entreprise/domain/entreprise_profile.dart';
import '../domain/entreprise_liee.dart';

final clientEntrepriseRepositoryProvider = Provider<ClientEntrepriseRepository>((ref) {
  return ClientEntrepriseRepository(ref.watch(apiClientProvider));
});

/// `GET /entreprises/profil` est réservé aux tokens Utilisateur (TenantId) —
/// le portail Client a son propre point d'entrée équivalent.
class ClientEntrepriseRepository {
  final Dio _dio;

  ClientEntrepriseRepository(this._dio);

  Future<EntrepriseProfile> getProfil() async {
    final response = await _dio.get('/clients/moi/entreprise');
    return EntrepriseProfile.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<EntrepriseLiee>> listEntreprisesLiees() async {
    final response = await _dio.get('/clients/moi/entreprises-liees');
    return (response.data as List)
        .map((json) => EntrepriseLiee.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<String> switchEntreprise(int clientId) async {
    final response = await _dio.post(
      '/clients/moi/switch-entreprise',
      data: {'client_id': clientId},
    );
    return response.data['access_token'] as String;
  }
}
