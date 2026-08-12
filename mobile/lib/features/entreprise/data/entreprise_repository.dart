import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/entreprise_profil.dart';

final entrepriseRepositoryProvider = Provider<EntrepriseRepository>((ref) {
  return EntrepriseRepository(ref.watch(apiClientProvider));
});

class EntrepriseRepository {
  final Dio _dio;

  EntrepriseRepository(this._dio);

  Future<EntrepriseProfil> getProfil() async {
    final response = await _dio.get('/entreprises/profil');
    return EntrepriseProfil.fromJson(response.data as Map<String, dynamic>);
  }
}
