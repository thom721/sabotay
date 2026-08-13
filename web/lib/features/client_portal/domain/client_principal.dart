import '../../clients/domain/client.dart';

/// Identité du Client connecté au portail libre-service — miroir de
/// `ClientRead` côté backend, distincte du `User` (Utilisateur
/// Admin/Manager/Agent) de `features/auth/domain/user.dart`. Réutilise
/// `StatutClient` déjà défini pour la fiche client côté Admin.
class ClientPrincipal {
  final String id;
  final String entrepriseId;
  final String nom;
  final String prenom;
  final String? email;
  final bool doitChangerMotDePasse;
  final StatutClient statut;

  const ClientPrincipal({
    required this.id,
    required this.entrepriseId,
    required this.nom,
    required this.prenom,
    this.email,
    required this.doitChangerMotDePasse,
    required this.statut,
  });

  String get nomComplet => '$prenom $nom'.trim();

  factory ClientPrincipal.fromJson(Map<String, dynamic> json) => ClientPrincipal(
        id: json['id'] as String,
        entrepriseId: json['entreprise_id'] as String,
        nom: json['nom'] as String,
        prenom: json['prenom'] as String? ?? '',
        email: json['email'] as String?,
        doitChangerMotDePasse: json['doit_changer_mot_de_passe'] as bool? ?? false,
        statut: statutClientFromString(json['statut'] as String),
      );
}
