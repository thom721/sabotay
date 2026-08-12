/// Une entreprise liée au même email Client que le compte actuellement
/// connecté — alimente le sélecteur d'entreprise du portail Client.
class EntrepriseLiee {
  final int clientId;
  final int entrepriseId;
  final String entrepriseNom;
  final bool actif;

  const EntrepriseLiee({
    required this.clientId,
    required this.entrepriseId,
    required this.entrepriseNom,
    required this.actif,
  });

  factory EntrepriseLiee.fromJson(Map<String, dynamic> json) => EntrepriseLiee(
        clientId: json['client_id'] as int,
        entrepriseId: json['entreprise_id'] as int,
        entrepriseNom: json['entreprise_nom'] as String,
        actif: json['actif'] as bool,
      );
}
