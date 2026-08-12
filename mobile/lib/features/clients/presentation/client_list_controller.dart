import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/client_repository.dart';
import '../domain/client.dart';

final clientListControllerProvider =
    AsyncNotifierProvider<ClientListController, List<Client>>(ClientListController.new);

class ClientListController extends AsyncNotifier<List<Client>> {
  @override
  Future<List<Client>> build() => ref.watch(clientRepositoryProvider).list();

  Future<void> refresh() async {
    state = const AsyncLoading<List<Client>>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => ref.read(clientRepositoryProvider).list());
  }
}
