/// Abonnement d'une entreprise, tel que vu par le super-admin.
class Abonnement {
  final String statut;
  final String? dateRenouvellement;
  final num? montant;

  const Abonnement({required this.statut, this.dateRenouvellement, this.montant});

  factory Abonnement.fromJson(Map<String, dynamic> json) => Abonnement(
        statut: json['statut'] as String,
        dateRenouvellement: json['date_renouvellement'] as String?,
        montant: json['montant'] as num?,
      );
}

/// Résumé d'une entreprise dans la liste `/superadmin/entreprises`.
class EntrepriseSummary {
  final String id;
  final String nom;
  final String devise;
  final String statut;
  final String dateCreation;
  final int nbEmployes;
  final int nbClients;
  final Abonnement? abonnement;
  // Vrai dès la première synchronisation réussie d'un poste bureau — voir
  // Entreprise.est_installe (backend). Un super-admin peut le repasser à
  // False (SuperAdminRepository.reinitialiserInstallation).
  final bool estInstalle;

  const EntrepriseSummary({
    required this.id,
    required this.nom,
    required this.devise,
    required this.statut,
    required this.dateCreation,
    required this.nbEmployes,
    required this.nbClients,
    required this.abonnement,
    required this.estInstalle,
  });

  factory EntrepriseSummary.fromJson(Map<String, dynamic> json) => EntrepriseSummary(
        id: json['id'] as String,
        nom: json['nom'] as String,
        devise: json['devise'] as String,
        statut: json['statut'] as String,
        dateCreation: json['date_creation'] as String,
        nbEmployes: json['nb_employes'] as int,
        nbClients: json['nb_clients'] as int,
        abonnement: json['abonnement'] == null
            ? null
            : Abonnement.fromJson(json['abonnement'] as Map<String, dynamic>),
        estInstalle: json['est_installe'] as bool,
      );
}
