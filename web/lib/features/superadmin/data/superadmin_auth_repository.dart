import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

final superAdminAuthRepositoryProvider = Provider<SuperAdminAuthRepository>((ref) {
  return SuperAdminAuthRepository(ref.watch(superAdminApiClientProvider));
});

class SuperAdminAuthRepository {
  final Dio _dio;

  SuperAdminAuthRepository(this._dio);

  /// Contrairement à `/auth/login` (staff), le backend attend ici un corps
  /// JSON simple `{email, password}`, pas un formulaire OAuth2.
  Future<String> login({required String email, required String password}) async {
    final response = await _dio.post(
      '/auth/superadmin-login',
      data: {'email': email, 'password': password},
    );
    return response.data['access_token'] as String;
  }
}
