enum RoleUtilisateur { admin, manager, agent }

RoleUtilisateur roleFromString(String value) => RoleUtilisateur.values.firstWhere(
      (r) => r.name == value,
      orElse: () => RoleUtilisateur.agent,
    );

String roleLabel(RoleUtilisateur role) => switch (role) {
      RoleUtilisateur.admin => 'Admin',
      RoleUtilisateur.manager => 'Manager',
      RoleUtilisateur.agent => 'Agent',
    };

class User {
  final int id;
  final int entrepriseId;
  final String nom;
  final String telephone;
  final String? email;
  final RoleUtilisateur role;
  final bool doitChangerMotDePasse;

  const User({
    required this.id,
    required this.entrepriseId,
    required this.nom,
    required this.telephone,
    required this.email,
    required this.role,
    required this.doitChangerMotDePasse,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        entrepriseId: json['entreprise_id'] as int,
        nom: json['nom'] as String,
        telephone: json['telephone'] as String,
        email: json['email'] as String?,
        role: roleFromString(json['role'] as String),
        doitChangerMotDePasse: json['doit_changer_mot_de_passe'] as bool? ?? false,
      );
}
