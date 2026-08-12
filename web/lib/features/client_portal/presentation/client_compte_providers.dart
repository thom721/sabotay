import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../comptes/domain/compte_sabotay.dart';
import '../data/client_compte_repository.dart';

final clientMesComptesProvider = FutureProvider<List<CompteSabotay>>((ref) {
  return ref.watch(clientCompteRepositoryProvider).listMesComptes();
});

final clientCompteSoldeProvider = FutureProvider.family<CompteSolde, int>((ref, compteId) {
  return ref.watch(clientCompteRepositoryProvider).getSolde(compteId);
});

final clientTransactionsProvider = FutureProvider.family((ref, int compteId) {
  return ref.watch(clientCompteRepositoryProvider).getTransactions(compteId);
});

/// Compte actuellement affiché par le portail Client — utile quand le
/// client a plusieurs comptes Sabotay, partagé entre Dashboard et
/// Historique pour que la sélection persiste en changeant d'écran.
final clientCompteSelectionneProvider = StateProvider<int?>((ref) => null);
