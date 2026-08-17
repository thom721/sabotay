import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/local_db_service.dart';
import '../domain/entreprise_profil.dart';

final entrepriseRepositoryProvider = Provider<EntrepriseRepository>((ref) {
  return EntrepriseRepository(ref.watch(apiClientProvider));
});

/// Cache-first (Epic 6) — voir `ClientRepository` pour le principe général.
class EntrepriseRepository {
  final Dio _dio;

  EntrepriseRepository(this._dio);

  Future<EntrepriseProfil> getProfil() async {
    final cached = await LocalDbService.instance.getProfil();
    if (cached != null) return cached;

    final response = await _dio.get('/entreprises/profil');
    final profil = EntrepriseProfil.fromJson(response.data as Map<String, dynamic>);
    await LocalDbService.instance.upsertProfil(profil);
    return profil;
  }
}
