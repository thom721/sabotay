import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/client_principal.dart';

final clientAuthRepositoryProvider = Provider<ClientAuthRepository>((ref) {
  return ClientAuthRepository(ref.watch(apiClientProvider));
});

/// Authentification du portail Client — endpoints déjà existants côté
/// backend (`backend/app/api/v1/endpoints/client_auth.py`) mais jamais
/// branchés côté mobile avant. Contrairement à `AuthRepository.login`
/// (formulaire OAuth2), `/auth/client-login` attend du JSON.
class ClientAuthRepository {
  final Dio _dio;

  ClientAuthRepository(this._dio);

  Future<String> login({required String email, required String password}) async {
    final response = await _dio.post(
      '/auth/client-login',
      data: {'email': email, 'password': password},
    );
    return response.data['access_token'] as String;
  }

  Future<ClientPrincipal> fetchMe() async {
    final response = await _dio.get('/clients/moi');
    return ClientPrincipal.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> changePassword({
    required String motDePasseActuel,
    required String nouveauMotDePasse,
  }) async {
    await _dio.patch(
      '/auth/client/mot-de-passe',
      data: {
        'mot_de_passe_actuel': motDePasseActuel,
        'nouveau_mot_de_passe': nouveauMotDePasse,
      },
    );
  }
}
