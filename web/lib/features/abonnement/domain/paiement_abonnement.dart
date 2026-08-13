/// Un paiement de l'abonnement plateforme (historique — `GET
/// /abonnement/paiements`, ou `GET /superadmin/entreprises/{id}/paiements`
/// côté super-admin).
class PaiementAbonnement {
  final String id;
  final num montant;
  final String? moncashOrderId;
  final String? moncashTransactionId;
  final DateTime datePaiement;
  // Qui a déclenché la confirmation — null pour les paiements antérieurs à
  // l'ajout de ce champ (voir migration 0026).
  final String? payeParNom;

  const PaiementAbonnement({
    required this.id,
    required this.montant,
    required this.moncashOrderId,
    required this.moncashTransactionId,
    required this.datePaiement,
    required this.payeParNom,
  });

  factory PaiementAbonnement.fromJson(Map<String, dynamic> json) => PaiementAbonnement(
        id: json['id'] as String,
        montant: num.parse(json['montant'].toString()),
        moncashOrderId: json['moncash_order_id'] as String?,
        moncashTransactionId: json['moncash_transaction_id'] as String?,
        datePaiement: DateTime.parse(json['date_paiement'] as String),
        payeParNom: json['paye_par_nom'] as String?,
      );
}
