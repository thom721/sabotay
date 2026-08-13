enum StatutCompte { actif, enRetard, complete, annule, inactif }

StatutCompte statutCompteFromString(String value) => switch (value) {
      'en_retard' => StatutCompte.enRetard,
      _ => StatutCompte.values.firstWhere(
          (s) => s.name == value,
          orElse: () => StatutCompte.actif,
        ),
    };

/// Libellé français affiché pour un statut de compte.
String statutCompteLabel(StatutCompte s) => switch (s) {
      StatutCompte.actif => 'Actif',
      StatutCompte.enRetard => 'En retard',
      StatutCompte.complete => 'Complété',
      StatutCompte.annule => 'Annulé',
      StatutCompte.inactif => 'Inactif',
    };

class CompteSabotay {
  final String id;
  final String entrepriseId;
  final String clientId;
  final String numeroCompte;
  final num montantJournalier;
  final DateTime dateDebut;
  final int dureeJours;
  final DateTime dateFinPrevue;
  final num montantTotalAttendu;
  final StatutCompte statut;

  const CompteSabotay({
    required this.id,
    required this.entrepriseId,
    required this.clientId,
    required this.numeroCompte,
    required this.montantJournalier,
    required this.dateDebut,
    required this.dureeJours,
    required this.dateFinPrevue,
    required this.montantTotalAttendu,
    required this.statut,
  });

  factory CompteSabotay.fromJson(Map<String, dynamic> json) => CompteSabotay(
        id: json['id'] as String,
        entrepriseId: json['entreprise_id'] as String,
        clientId: json['client_id'] as String,
        numeroCompte: json['numero_compte'] as String,
        // Le backend sérialise les montants Decimal en chaînes (ex. "250.00").
        montantJournalier: num.parse(json['montant_journalier'].toString()),
        dateDebut: DateTime.parse(json['date_debut'] as String),
        dureeJours: json['duree_jours'] as int,
        dateFinPrevue: DateTime.parse(json['date_fin_prevue'] as String),
        montantTotalAttendu: num.parse(json['montant_total_attendu'].toString()),
        statut: statutCompteFromString(json['statut'] as String),
      );
}

class CompteSolde {
  final String compteId;
  final num montantTotalAttendu;
  final num montantCollecte;
  final num montantRetire;
  final num soldeRestant;
  final num soldeDisponible;
  final num dette;
  final int joursManques;

  const CompteSolde({
    required this.compteId,
    required this.montantTotalAttendu,
    required this.montantCollecte,
    required this.montantRetire,
    required this.soldeRestant,
    required this.soldeDisponible,
    required this.dette,
    required this.joursManques,
  });

  factory CompteSolde.fromJson(Map<String, dynamic> json) => CompteSolde(
        compteId: json['compte_id'] as String,
        montantTotalAttendu: num.parse(json['montant_total_attendu'].toString()),
        montantCollecte: num.parse(json['montant_collecte'].toString()),
        montantRetire: num.parse(json['montant_retire'].toString()),
        soldeRestant: num.parse(json['solde_restant'].toString()),
        soldeDisponible: num.parse(json['solde_disponible'].toString()),
        dette: num.parse(json['dette'].toString()),
        joursManques: json['jours_manques'] as int,
      );
}
