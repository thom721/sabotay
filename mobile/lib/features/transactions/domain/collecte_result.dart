import 'transaction.dart';

/// Résultat de `TransactionRepository.create()` — distingue une collecte
/// confirmée par le serveur d'une collecte mise en file d'attente hors-
/// ligne (réseau indisponible au moment de l'envoi). Le second cas n'est
/// pas une erreur : la saisie de l'agent n'est jamais perdue.
sealed class CollecteResult {
  const CollecteResult();
}

class CollecteSuccess extends CollecteResult {
  final Transaction transaction;

  const CollecteSuccess(this.transaction);
}

/// Valeurs provisoires (saisies localement, jamais confirmées par le
/// serveur) — pas d'id, pas de collecte_par_nom, pas de garantie que le
/// montant sera exactement celui-ci une fois rejoué (le serveur recalcule
/// toujours nb_jours * montant_journalier au moment réel de la synchro).
class CollecteQueued extends CollecteResult {
  final String compteId;
  final DateTime date;
  final int nbJours;
  final num montant;

  const CollecteQueued({
    required this.compteId,
    required this.date,
    required this.nbJours,
    required this.montant,
  });
}
