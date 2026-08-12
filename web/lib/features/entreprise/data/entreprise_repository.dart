import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/entreprise_profile.dart';

final entrepriseRepositoryProvider = Provider<EntrepriseRepository>((ref) {
  return EntrepriseRepository(ref.watch(apiClientProvider));
});

/// Fiche entreprise (informations générales, format de reçu) — PRD §8.5.
/// Accessible en lecture à tout le staff, modifiable par l'Admin uniquement.
final entrepriseProfileProvider = FutureProvider<EntrepriseProfile>((ref) {
  return ref.watch(entrepriseRepositoryProvider).getProfile();
});

class EntrepriseRepository {
  final Dio _dio;

  EntrepriseRepository(this._dio);

  Future<EntrepriseProfile> getProfile() async {
    final response = await _dio.get('/entreprises/profil');
    return EntrepriseProfile.fromJson(response.data as Map<String, dynamic>);
  }

  Future<EntrepriseProfile> updateProfile({
    String? nom,
    String? adresse,
    String? telephoneContact,
    String? formatRecu,
    String? texteBasRecu,
  }) async {
    final data = <String, dynamic>{};
    if (nom != null) data['nom'] = nom;
    if (adresse != null) data['adresse'] = adresse;
    if (telephoneContact != null) data['telephone_contact'] = telephoneContact;
    if (formatRecu != null) data['format_recu'] = formatRecu;
    if (texteBasRecu != null) data['texte_bas_recu'] = texteBasRecu;

    final response = await _dio.patch('/entreprises/profil', data: data);
    return EntrepriseProfile.fromJson(response.data as Map<String, dynamic>);
  }
}
