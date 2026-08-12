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

  Future<Client> getOne(int id) async {
    final response = await _dio.get('/clients/$id');
    return Client.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Client> create({
    required String nom,
    required String prenom,
    required String telephone,
    String? adresse,
    DateTime? dateNaissance,
    String? nifCin,
    String? email,
    String? heritierNom,
    String? heritierPrenom,
    String? heritierAdresse,
    String? heritierTelephone,
    int? agentAssigneId,
  }) async {
    final response = await _dio.post(
      '/clients',
      data: {
        'nom': nom,
        'prenom': prenom,
        'telephone': telephone,
        'adresse': adresse,
        'date_naissance': dateNaissance == null
            ? null
            : '${dateNaissance.year.toString().padLeft(4, '0')}-'
                '${dateNaissance.month.toString().padLeft(2, '0')}-'
                '${dateNaissance.day.toString().padLeft(2, '0')}',
        'nif_cin': nifCin,
        'email': email,
        'heritier_nom': heritierNom,
        'heritier_prenom': heritierPrenom,
        'heritier_adresse': heritierAdresse,
        'heritier_telephone': heritierTelephone,
        'agent_assigne_id': agentAssigneId,
      },
    );
    return Client.fromJson(response.data as Map<String, dynamic>);
  }

  /// Assigne/réassigne un client à un agent (PRD §8.2). `agentId: null`
  /// retire l'assignation.
  Future<Client> assignAgent(int clientId, int? agentId) async {
    final response = await _dio.patch(
      '/clients/$clientId/agent',
      data: {'agent_assigne_id': agentId},
    );
    return Client.fromJson(response.data as Map<String, dynamic>);
  }
}
