/// Un point de la série temporelle du tableau de bord (`GET
/// /dashboard/serie-temporelle`) — montants collectés/retirés et nouveaux
/// clients sur un bucket (jour/semaine/mois/année selon la période choisie).
class PointSerieTemporelle {
  final String label;
  final num montantCollecte;
  final num montantRetrait;
  final int nbNouveauxClients;

  const PointSerieTemporelle({
    required this.label,
    required this.montantCollecte,
    required this.montantRetrait,
    required this.nbNouveauxClients,
  });

  factory PointSerieTemporelle.fromJson(Map<String, dynamic> json) => PointSerieTemporelle(
        label: json['label'] as String,
        montantCollecte: num.parse(json['montant_collecte'].toString()),
        montantRetrait: num.parse(json['montant_retrait'].toString()),
        nbNouveauxClients: json['nb_nouveaux_clients'] as int,
      );
}
