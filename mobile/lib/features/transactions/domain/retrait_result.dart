import 'transaction.dart';

/// Résultat de `TransactionRepository.createRetrait()` — même principe que
/// `CollecteResult` (voir `collecte_result.dart`) : distingue un retrait
/// confirmé par le serveur d'un retrait mis en file d'attente hors-ligne.
/// Activé à l'Epic 6 maintenant qu'un solde caché (même légèrement daté)
/// permet une vérification côté client avant l'envoi — la validation qui
/// fait foi reste côté serveur au moment de la synchro.
sealed class RetraitResult {
  const RetraitResult();
}

class RetraitSuccess extends RetraitResult {
  final Transaction transaction;

  const RetraitSuccess(this.transaction);
}

/// Valeurs provisoires — pas d'id, pas de garantie que le retrait aboutira
/// une fois rejoué (le solde réel peut avoir changé entre-temps, ex. deux
/// appareils) : dans ce cas, l'opération est abandonnée après plusieurs
/// tentatives (voir `OfflineQueueService.dropped`) et l'agent est prévenu,
/// jamais une perte silencieuse.
class RetraitQueued extends RetraitResult {
  final String compteId;
  final DateTime date;
  final num montant;

  const RetraitQueued({
    required this.compteId,
    required this.date,
    required this.montant,
  });
}
