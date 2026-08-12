/// Statistiques globales de la plateforme (`/superadmin/statistiques`).
///
/// Les champs monétaires sont parsés défensivement via `num.parse` : ce
/// backend a déjà renvoyé des montants sous forme de chaînes JSON ailleurs
/// (ex. "50.00"), donc on ne suppose jamais qu'ils arrivent en `num`.
class PlatformStatistiques {
  final int nbEntreprisesTotal;
  final int nbEntreprisesAbonnementActif;
  final int nbClientsTotal;
  final int nbEmployesTotal;
  final num montantTotalCollecte;
  final num montantAbonnementsCollecte;

  const PlatformStatistiques({
    required this.nbEntreprisesTotal,
    required this.nbEntreprisesAbonnementActif,
    required this.nbClientsTotal,
    required this.nbEmployesTotal,
    required this.montantTotalCollecte,
    required this.montantAbonnementsCollecte,
  });

  factory PlatformStatistiques.fromJson(Map<String, dynamic> json) => PlatformStatistiques(
        nbEntreprisesTotal: json['nb_entreprises_total'] as int,
        nbEntreprisesAbonnementActif: json['nb_entreprises_abonnement_actif'] as int,
        nbClientsTotal: json['nb_clients_total'] as int,
        nbEmployesTotal: json['nb_employes_total'] as int,
        montantTotalCollecte: num.parse(json['montant_total_collecte'].toString()),
        montantAbonnementsCollecte: num.parse(json['montant_abonnements_collecte'].toString()),
      );
}
