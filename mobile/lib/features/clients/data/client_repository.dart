import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/client.dart';

final clientRepositoryProvider = Provider<ClientRepository>((ref) {
  return ClientRepository(ref.watch(apiClientProvider));
});

class ClientRepository {
  final Dio _dio;

  ClientRepository(this._dio);

  /// Le backend filtre déjà côté serveur selon le rôle : un agent ne reçoit
  /// que ses clients assignés, Admin/Manager reçoivent tout (PRD §6).
  Future<List<Client>> list() async {
    final response = await _dio.get('/clients');
    return (response.data as List)
        .map((json) => Client.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Client> getById(String clientId) async {
    final response = await _dio.get('/clients/$clientId');
    return Client.fromJson(response.data as Map<String, dynamic>);
  }
}
