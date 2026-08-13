enum StatutClient { actif, inactif }

StatutClient statutClientFromString(String value) => StatutClient.values.firstWhere(
      (s) => s.name == value,
      orElse: () => StatutClient.actif,
    );

class Client {
  final String id;
  final String entrepriseId;
  final String nom;
  final String prenom;
  final String telephone;
  final String? adresse;
  final DateTime? dateNaissance;
  final String? nifCin;
  final String? photoUrl;
  final String? email;
  final String? agentAssigneId;
  final DateTime? derniereConnexion;
  final String? heritierNom;
  final String? heritierPrenom;
  final String? heritierAdresse;
  final String? heritierTelephone;
  final StatutClient statut;

  const Client({
    required this.id,
    required this.entrepriseId,
    required this.nom,
    required this.prenom,
    required this.telephone,
    required this.adresse,
    required this.dateNaissance,
    required this.nifCin,
    required this.photoUrl,
    required this.email,
    required this.agentAssigneId,
    required this.derniereConnexion,
    required this.heritierNom,
    required this.heritierPrenom,
    required this.heritierAdresse,
    required this.heritierTelephone,
    required this.statut,
  });

  String get nomComplet => '$prenom $nom'.trim();

  bool get aHeritier =>
      (heritierNom?.isNotEmpty ?? false) || (heritierPrenom?.isNotEmpty ?? false);

  factory Client.fromJson(Map<String, dynamic> json) => Client(
        id: json['id'] as String,
        entrepriseId: json['entreprise_id'] as String,
        nom: json['nom'] as String,
        prenom: json['prenom'] as String? ?? '',
        telephone: json['telephone'] as String,
        adresse: json['adresse'] as String?,
        dateNaissance: json['date_naissance'] != null
            ? DateTime.tryParse(json['date_naissance'] as String)
            : null,
        nifCin: json['nif_cin'] as String?,
        photoUrl: json['photo_url'] as String?,
        email: json['email'] as String?,
        agentAssigneId: json['agent_assigne_id'] as String?,
        derniereConnexion: json['derniere_connexion'] != null
            ? DateTime.tryParse(json['derniere_connexion'] as String)
            : null,
        heritierNom: json['heritier_nom'] as String?,
        heritierPrenom: json['heritier_prenom'] as String?,
        heritierAdresse: json['heritier_adresse'] as String?,
        heritierTelephone: json['heritier_telephone'] as String?,
        statut: statutClientFromString(json['statut'] as String),
      );
}
