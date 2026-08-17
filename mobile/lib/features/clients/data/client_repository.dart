import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/local_db_service.dart';
import '../domain/client.dart';

final clientRepositoryProvider = Provider<ClientRepository>((ref) {
  return ClientRepository(ref.watch(apiClientProvider));
});

/// Cache-first (Epic 6) : lit d'abord le cache local (peuplé/rafraîchi par
/// `OfflineCacheService`, voir `offline_drain_controller.dart`) ; ne
/// retombe sur le réseau que si le cache est vide (premier lancement,
/// avant le premier cycle de sync). Le backend filtre déjà côté serveur
/// selon le rôle : un agent ne reçoit que ses clients assignés, Admin/
/// Manager reçoivent tout (PRD §6) — reflété tel quel dans le cache par
/// `OfflineCacheService._syncClients`.
class ClientRepository {
  final Dio _dio;

  ClientRepository(this._dio);

  Future<List<Client>> list() async {
    final cached = await LocalDbService.instance.getClients();
    if (cached.isNotEmpty) return cached;

    final response = await _dio.get('/clients');
    final clients = (response.data as List)
        .map((json) => Client.fromJson(json as Map<String, dynamic>))
        .toList();
    await LocalDbService.instance.upsertClients(clients);
    return clients;
  }

  Future<Client> getById(String clientId) async {
    final cached = await LocalDbService.instance.getClient(clientId);
    if (cached != null) return cached;

    final response = await _dio.get('/clients/$clientId');
    final client = Client.fromJson(response.data as Map<String, dynamic>);
    await LocalDbService.instance.upsertClients([client]);
    return client;
  }
}
