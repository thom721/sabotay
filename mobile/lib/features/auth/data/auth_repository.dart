import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/user.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});

/// Pas d'inscription ni de réinitialisation de mot de passe ici — réservées
/// au web (PRD §5.3). Le mobile ne fait que se connecter avec un compte déjà
/// créé côté web par un Admin, et changer son mot de passe une fois connecté.
class AuthRepository {
  final Dio _dio;

  AuthRepository(this._dio);

  /// Le backend attend un formulaire OAuth2 standard (username/password),
  /// pas du JSON.
  Future<String> login({required String identifiant, required String password}) async {
    final response = await _dio.post(
      '/auth/login',
      data: FormData.fromMap({'username': identifiant, 'password': password}),
    );
    return response.data['access_token'] as String;
  }

  Future<User> fetchCurrentUser() async {
    final response = await _dio.get('/auth/me');
    return User.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> changePassword({
    required String motDePasseActuel,
    required String nouveauMotDePasse,
  }) async {
    await _dio.patch(
      '/auth/mot-de-passe',
      data: {
        'mot_de_passe_actuel': motDePasseActuel,
        'nouveau_mot_de_passe': nouveauMotDePasse,
      },
    );
  }
}
