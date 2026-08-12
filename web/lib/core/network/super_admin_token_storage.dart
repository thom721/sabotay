import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stockage du jeton super-admin, complètement distinct de [TokenStorage]
/// (clé de stockage sécurisé différente) : les deux jetons ne doivent jamais
/// se chevaucher, la session super-admin étant un principal séparé de la
/// session staff/client.
final superAdminTokenStorageProvider =
    Provider<SuperAdminTokenStorage>((ref) => SuperAdminTokenStorage());

class SuperAdminTokenStorage {
  static const _tokenKey = 'superadmin_access_token';

  final _storage = const FlutterSecureStorage();

  Future<void> save(String token) => _storage.write(key: _tokenKey, value: token);

  Future<String?> read() => _storage.read(key: _tokenKey);

  Future<void> clear() => _storage.delete(key: _tokenKey);
}
