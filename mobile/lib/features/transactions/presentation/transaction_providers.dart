import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/transaction_repository.dart';
import '../domain/transaction.dart';

final transactionsForCompteProvider =
    FutureProvider.family<List<Transaction>, int>((ref, compteId) {
  return ref.watch(transactionRepositoryProvider).listForCompte(compteId);
});
