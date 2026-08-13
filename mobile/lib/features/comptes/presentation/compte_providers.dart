import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/compte_repository.dart';
import '../domain/compte_sabotay.dart';

final comptesForClientProvider =
    FutureProvider.family<List<CompteSabotay>, String>((ref, clientId) {
  return ref.watch(compteRepositoryProvider).listForClient(clientId);
});

final compteSoldeProvider = FutureProvider.family<CompteSolde, String>((ref, compteId) {
  return ref.watch(compteRepositoryProvider).getSolde(compteId);
});
