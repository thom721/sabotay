/// Libellé français affiché pour un statut d'abonnement.
String statutAbonnementLabel(String statut) => switch (statut) {
      'essai' => 'Essai gratuit',
      'actif' => 'Actif',
      'suspendu' => 'Suspendu',
      'annule' => 'Annulé',
      _ => statut,
    };

/// Abonnement SabotayPro de l'entreprise (PRD — paiement annuel via
/// MonCash). `statut` : "essai" | "actif" | "suspendu" | "annule".
class Abonnement {
  final int id;
  final int entrepriseId;
  final String plan;
  final String statut;
  final num montant;
  final DateTime? dateDebut;
  final DateTime? dateRenouvellement;
  final DateTime? datePaiement;

  const Abonnement({
    required this.id,
    required this.entrepriseId,
    required this.plan,
    required this.statut,
    required this.montant,
    required this.dateDebut,
    required this.dateRenouvellement,
    required this.datePaiement,
  });

  bool get estActif => statut == 'actif';

  factory Abonnement.fromJson(Map<String, dynamic> json) => Abonnement(
        id: json['id'] as int,
        entrepriseId: json['entreprise_id'] as int,
        plan: json['plan'] as String,
        statut: json['statut'] as String,
        // Le backend sérialise les montants Decimal en chaînes (ex. "100.00").
        montant: num.parse(json['montant'].toString()),
        dateDebut: json['date_debut'] == null
            ? null
            : DateTime.tryParse(json['date_debut'] as String),
        dateRenouvellement: json['date_renouvellement'] == null
            ? null
            : DateTime.tryParse(json['date_renouvellement'] as String),
        datePaiement: json['date_paiement'] == null
            ? null
            : DateTime.tryParse(json['date_paiement'] as String),
      );
}
