import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/compte_repository.dart';
import '../domain/compte_sabotay.dart';

/// Comptes Sabotay d'un client donné (fiche client, PRD §8.4).
final clientComptesProvider =
    FutureProvider.family<List<CompteSabotay>, String>((ref, clientId) {
  return ref.watch(compteRepositoryProvider).listForClient(clientId);
});

/// Solde d'un compte Sabotay donné.
final compteSoldeProvider = FutureProvider.family<CompteSolde, String>((ref, compteId) {
  return ref.watch(compteRepositoryProvider).getSolde(compteId);
});
