import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/client_repository.dart';
import '../domain/client.dart';

final clientListControllerProvider =
    AsyncNotifierProvider<ClientListController, List<Client>>(ClientListController.new);

/// Fiche d'un client précis (écran de détail, PRD §8.4).
final clientDetailProvider = FutureProvider.family<Client, String>((ref, clientId) {
  return ref.watch(clientRepositoryProvider).getOne(clientId);
});

class ClientListController extends AsyncNotifier<List<Client>> {
  @override
  Future<List<Client>> build() => ref.watch(clientRepositoryProvider).list();

  Future<void> refresh() async {
    state = const AsyncLoading<List<Client>>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => ref.read(clientRepositoryProvider).list());
  }

  Future<void> addClient({
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
  }) async {
    await ref.read(clientRepositoryProvider).create(
          nom: nom,
          prenom: prenom,
          telephone: telephone,
          adresse: adresse,
          dateNaissance: dateNaissance,
          nifCin: nifCin,
          email: email,
          heritierNom: heritierNom,
          heritierPrenom: heritierPrenom,
          heritierAdresse: heritierAdresse,
          heritierTelephone: heritierTelephone,
        );
    await refresh();
  }

  Future<void> assignAgent(String clientId, String? agentId) async {
    await ref.read(clientRepositoryProvider).assignAgent(clientId, agentId);
    await refresh();
  }
}
