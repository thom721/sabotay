import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/compte_repository.dart';
import '../domain/compte_sabotay.dart';

final comptesForClientProvider =
    FutureProvider.family<List<CompteSabotay>, int>((ref, clientId) {
  return ref.watch(compteRepositoryProvider).listForClient(clientId);
});

final compteSoldeProvider = FutureProvider.family<CompteSolde, int>((ref, compteId) {
  return ref.watch(compteRepositoryProvider).getSolde(compteId);
});
