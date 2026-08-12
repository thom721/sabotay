import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/user.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});

class AuthRepository {
  final Dio _dio;

  AuthRepository(this._dio);

  /// Le backend attend un formulaire OAuth2 standard (username/password),
  /// pas du JSON — d'où FormData plutôt qu'un simple corps JSON.
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

  /// Inscription self-service d'une entreprise + son premier compte Admin
  /// (PRD §7.1, §8.1). Ne connecte pas automatiquement l'utilisateur —
  /// à faire via login() ensuite avec les mêmes identifiants.
  Future<void> registerEntreprise({
    required String nomEntreprise,
    required String devise,
    required String adminNom,
    required String adminTelephone,
    String? adminEmail,
    required String adminPassword,
  }) async {
    await _dio.post(
      '/entreprises/register',
      data: {
        'nom_entreprise': nomEntreprise,
        'devise': devise,
        'admin_nom': adminNom,
        'admin_telephone': adminTelephone,
        'admin_email': adminEmail,
        'admin_password': adminPassword,
      },
    );
  }

  /// Demande un code de réinitialisation (SMS ou email, au choix). Le backend
  /// répond toujours de façon générique, que le compte existe ou non.
  Future<void> requestPasswordReset({
    required String identifiant,
    required String canal,
  }) async {
    await _dio.post(
      '/auth/mot-de-passe-oublie',
      data: {'identifiant': identifiant, 'canal': canal},
    );
  }

  Future<void> confirmPasswordReset({
    required String identifiant,
    required String code,
    required String nouveauMotDePasse,
  }) async {
    await _dio.post(
      '/auth/reinitialiser-mot-de-passe',
      data: {
        'identifiant': identifiant,
        'code': code,
        'nouveau_mot_de_passe': nouveauMotDePasse,
      },
    );
  }

  /// Changement de mot de passe depuis l'espace connecté (PRD §8.5). Le
  /// backend renvoie 400 si le mot de passe actuel est incorrect.
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
