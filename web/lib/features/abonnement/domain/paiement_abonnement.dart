/// Un paiement de l'abonnement plateforme (historique — `GET
/// /abonnement/paiements`, ou `GET /superadmin/entreprises/{id}/paiements`
/// côté super-admin).
class PaiementAbonnement {
  final String id;
  final num montant;
  // "moncash" | "especes" — voir migration 0027.
  final String methode;
  // "confirme" | "en_attente" | "rejete" — un paiement espèces reste
  // en_attente jusqu'à confirmation superadmin.
  final String statut;
  final String? moncashOrderId;
  final String? moncashTransactionId;
  final DateTime datePaiement;
  // Qui a déclenché la confirmation — null pour les paiements antérieurs à
  // l'ajout de ce champ (voir migration 0026).
  final String? payeParNom;

  const PaiementAbonnement({
    required this.id,
    required this.montant,
    required this.methode,
    required this.statut,
    required this.moncashOrderId,
    required this.moncashTransactionId,
    required this.datePaiement,
    required this.payeParNom,
  });

  factory PaiementAbonnement.fromJson(Map<String, dynamic> json) => PaiementAbonnement(
        id: json['id'] as String,
        montant: num.parse(json['montant'].toString()),
        methode: json['methode'] as String,
        statut: json['statut'] as String,
        moncashOrderId: json['moncash_order_id'] as String?,
        moncashTransactionId: json['moncash_transaction_id'] as String?,
        datePaiement: DateTime.parse(json['date_paiement'] as String),
        payeParNom: json['paye_par_nom'] as String?,
      );
}

/// Paiement en attente, vue superadmin toutes entreprises confondues
/// (`GET /superadmin/paiements-en-attente`) — mêmes champs que
/// [PaiementAbonnement] plus l'identité de l'entreprise.
class PaiementEnAttente extends PaiementAbonnement {
  final String entrepriseId;
  final String entrepriseNom;

  const PaiementEnAttente({
    required super.id,
    required super.montant,
    required super.methode,
    required super.statut,
    required super.moncashOrderId,
    required super.moncashTransactionId,
    required super.datePaiement,
    required super.payeParNom,
    required this.entrepriseId,
    required this.entrepriseNom,
  });

  factory PaiementEnAttente.fromJson(Map<String, dynamic> json) => PaiementEnAttente(
        id: json['id'] as String,
        montant: num.parse(json['montant'].toString()),
        methode: json['methode'] as String,
        statut: json['statut'] as String,
        moncashOrderId: json['moncash_order_id'] as String?,
        moncashTransactionId: json['moncash_transaction_id'] as String?,
        datePaiement: DateTime.parse(json['date_paiement'] as String),
        payeParNom: json['paye_par_nom'] as String?,
        entrepriseId: json['entreprise_id'] as String,
        entrepriseNom: json['entreprise_nom'] as String,
      );
}
