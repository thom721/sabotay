enum StatutClient { actif, inactif }

StatutClient statutClientFromString(String value) => StatutClient.values.firstWhere(
      (s) => s.name == value,
      orElse: () => StatutClient.actif,
    );

class Client {
  final int id;
  final int entrepriseId;
  final String nom;
  final String prenom;
  final String telephone;
  final String? adresse;
  final DateTime? dateNaissance;
  final String? nifCin;
  final String? email;
  final bool doitChangerMotDePasse;
  final String? heritierNom;
  final String? heritierPrenom;
  final String? heritierAdresse;
  final String? heritierTelephone;
  final String? photoUrl;
  final int? agentAssigneId;
  final StatutClient statut;
  final DateTime? derniereConnexion;

  const Client({
    required this.id,
    required this.entrepriseId,
    required this.nom,
    required this.prenom,
    required this.telephone,
    required this.adresse,
    required this.dateNaissance,
    required this.nifCin,
    required this.email,
    required this.doitChangerMotDePasse,
    required this.heritierNom,
    required this.heritierPrenom,
    required this.heritierAdresse,
    required this.heritierTelephone,
    required this.photoUrl,
    required this.agentAssigneId,
    required this.statut,
    required this.derniereConnexion,
  });

  /// Nom complet "Prénom Nom", pour l'affichage.
  String get nomComplet => '$prenom $nom';

  /// Y a-t-il des informations d'héritier renseignées ?
  bool get aHeritier =>
      (heritierNom != null && heritierNom!.isNotEmpty) ||
      (heritierPrenom != null && heritierPrenom!.isNotEmpty) ||
      (heritierAdresse != null && heritierAdresse!.isNotEmpty) ||
      (heritierTelephone != null && heritierTelephone!.isNotEmpty);

  factory Client.fromJson(Map<String, dynamic> json) => Client(
        id: json['id'] as int,
        entrepriseId: json['entreprise_id'] as int,
        nom: json['nom'] as String,
        prenom: json['prenom'] as String? ?? '',
        telephone: json['telephone'] as String,
        adresse: json['adresse'] as String?,
        dateNaissance: json['date_naissance'] == null
            ? null
            : DateTime.parse(json['date_naissance'] as String),
        nifCin: json['nif_cin'] as String?,
        email: json['email'] as String?,
        doitChangerMotDePasse: json['doit_changer_mot_de_passe'] as bool? ?? false,
        heritierNom: json['heritier_nom'] as String?,
        heritierPrenom: json['heritier_prenom'] as String?,
        heritierAdresse: json['heritier_adresse'] as String?,
        heritierTelephone: json['heritier_telephone'] as String?,
        photoUrl: json['photo_url'] as String?,
        agentAssigneId: json['agent_assigne_id'] as int?,
        statut: statutClientFromString(json['statut'] as String),
        derniereConnexion: json['derniere_connexion'] == null
            ? null
            : DateTime.tryParse(json['derniere_connexion'] as String),
      );
}
