import '../../auth/domain/user.dart';

enum StatutUtilisateur { actif, inactif }

StatutUtilisateur statutUtilisateurFromString(String value) =>
    StatutUtilisateur.values.firstWhere(
      (s) => s.name == value,
      orElse: () => StatutUtilisateur.actif,
    );

class Employee {
  final String id;
  final String entrepriseId;
  final String nom;
  final String prenom;
  final String telephone;
  final String? email;
  final DateTime? dateNaissance;
  final String? nifCin;
  final String? adresse;
  final RoleUtilisateur role;
  final StatutUtilisateur statut;
  final bool doitChangerMotDePasse;
  final DateTime? derniereConnexion;
  /// Présents uniquement dans la réponse juste après la création — indique
  /// si l'email de bienvenue a pu être livré, et si non, le mot de passe à
  /// communiquer manuellement (jamais renvoyé par le backend autrement).
  final bool? emailEnvoye;
  final String? motDePasseTemporaire;

  const Employee({
    required this.id,
    required this.entrepriseId,
    required this.nom,
    required this.prenom,
    required this.telephone,
    required this.email,
    required this.dateNaissance,
    required this.nifCin,
    required this.adresse,
    required this.role,
    required this.statut,
    required this.doitChangerMotDePasse,
    required this.derniereConnexion,
    this.emailEnvoye,
    this.motDePasseTemporaire,
  });

  /// Nom complet "Prénom Nom", pour l'affichage.
  String get nomComplet => '$prenom $nom';

  factory Employee.fromJson(Map<String, dynamic> json) => Employee(
        id: json['id'] as String,
        entrepriseId: json['entreprise_id'] as String,
        nom: json['nom'] as String,
        prenom: json['prenom'] as String? ?? '',
        telephone: json['telephone'] as String,
        email: json['email'] as String?,
        dateNaissance: json['date_naissance'] == null
            ? null
            : DateTime.parse(json['date_naissance'] as String),
        nifCin: json['nif_cin'] as String?,
        adresse: json['adresse'] as String?,
        role: roleFromString(json['role'] as String),
        statut: statutUtilisateurFromString(json['statut'] as String),
        doitChangerMotDePasse: json['doit_changer_mot_de_passe'] as bool? ?? false,
        derniereConnexion: json['derniere_connexion'] == null
            ? null
            : DateTime.tryParse(json['derniere_connexion'] as String),
        emailEnvoye: json['email_envoye'] as bool?,
        motDePasseTemporaire: json['mot_de_passe_temporaire'] as String?,
      );
}
