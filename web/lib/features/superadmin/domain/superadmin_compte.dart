/// Compte super-admin (`/superadmin/comptes`) — jamais de mot de passe côté
/// client, le backend ne le renvoie pas.
class SuperAdminCompte {
  final String id;
  final String nom;
  final String email;
  final String statut;
  final String dateCreation;
  final String? derniereConnexion;

  const SuperAdminCompte({
    required this.id,
    required this.nom,
    required this.email,
    required this.statut,
    required this.dateCreation,
    required this.derniereConnexion,
  });

  factory SuperAdminCompte.fromJson(Map<String, dynamic> json) => SuperAdminCompte(
        id: json['id'] as String,
        nom: json['nom'] as String,
        email: json['email'] as String,
        statut: json['statut'] as String,
        dateCreation: json['date_creation'] as String,
        derniereConnexion: json['derniere_connexion'] as String?,
      );
}
