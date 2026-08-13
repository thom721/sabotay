import 'entreprise_summary.dart';

/// Utilisateur (staff) d'une entreprise, tel que vu par le super-admin.
class SuperAdminUtilisateur {
  final String id;
  final String nom;
  final String? prenom;
  final String? email;
  final String role;
  final String statut;
  final String? derniereConnexion;

  const SuperAdminUtilisateur({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.role,
    required this.statut,
    required this.derniereConnexion,
  });

  factory SuperAdminUtilisateur.fromJson(Map<String, dynamic> json) => SuperAdminUtilisateur(
        id: json['id'] as String,
        nom: json['nom'] as String,
        prenom: json['prenom'] as String?,
        email: json['email'] as String?,
        role: json['role'] as String,
        statut: json['statut'] as String,
        derniereConnexion: json['derniere_connexion'] as String?,
      );
}

/// Client d'une entreprise, tel que vu par le super-admin.
class SuperAdminClient {
  final String id;
  final String nom;
  final String prenom;
  final String telephone;
  final String? email;
  final String statut;
  final String? derniereConnexion;

  const SuperAdminClient({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.telephone,
    required this.email,
    required this.statut,
    required this.derniereConnexion,
  });

  factory SuperAdminClient.fromJson(Map<String, dynamic> json) => SuperAdminClient(
        id: json['id'] as String,
        nom: json['nom'] as String,
        prenom: json['prenom'] as String,
        telephone: json['telephone'] as String,
        email: json['email'] as String?,
        statut: json['statut'] as String,
        derniereConnexion: json['derniere_connexion'] as String?,
      );
}

/// Détail complet d'une entreprise (`/superadmin/entreprises/{id}`) : les
/// champs du résumé, plus la liste intégrale des utilisateurs et des
/// clients de cette entreprise.
class EntrepriseDetail {
  final EntrepriseSummary summary;
  final List<SuperAdminUtilisateur> utilisateurs;
  final List<SuperAdminClient> clients;

  const EntrepriseDetail({
    required this.summary,
    required this.utilisateurs,
    required this.clients,
  });

  factory EntrepriseDetail.fromJson(Map<String, dynamic> json) => EntrepriseDetail(
        summary: EntrepriseSummary.fromJson(json),
        utilisateurs: (json['utilisateurs'] as List<dynamic>? ?? [])
            .map((e) => SuperAdminUtilisateur.fromJson(e as Map<String, dynamic>))
            .toList(),
        clients: (json['clients'] as List<dynamic>? ?? [])
            .map((e) => SuperAdminClient.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
