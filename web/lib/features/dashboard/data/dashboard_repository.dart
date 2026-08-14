import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/point_serie_temporelle.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(apiClientProvider));
});

/// Série temporelle (collecte/retrait/nouveaux clients) pour le graphique du
/// tableau de bord, selon la période choisie ('jour'|'semaine'|'mois'|'annee').
final serieTemporelleProvider =
    FutureProvider.family<List<PointSerieTemporelle>, String>((ref, periode) {
  return ref.watch(dashboardRepositoryProvider).getSerieTemporelle(periode);
});

/// Montant collecté depuis le début du mois en cours — GET
/// /dashboard/statistiques, jusqu'ici jamais consommé côté web.
final montantCollecteMoisProvider = FutureProvider<num>((ref) {
  return ref.watch(dashboardRepositoryProvider).getMontantCollecteMois();
});

class DashboardRepository {
  final Dio _dio;

  DashboardRepository(this._dio);

  Future<List<PointSerieTemporelle>> getSerieTemporelle(String periode) async {
    final response = await _dio.get(
      '/dashboard/serie-temporelle',
      queryParameters: {'periode': periode},
    );
    return (response.data['points'] as List<dynamic>)
        .map((e) => PointSerieTemporelle.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<num> getMontantCollecteMois() async {
    final response = await _dio.get('/dashboard/statistiques');
    return num.parse(response.data['montant_collecte_mois'].toString());
  }
}
