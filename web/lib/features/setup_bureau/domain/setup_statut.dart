/// État de la liaison au cloud d'un poste local (`GET /setup/statut`,
/// `POST /setup/connecter`) — n'a de sens que sur le binaire desktop bundlé
/// (Epic 5), jamais sur le web navigateur (voir setup_providers.dart).
class SetupStatut {
  final bool installationTerminee;
  final String? entrepriseNom;

  const SetupStatut({required this.installationTerminee, this.entrepriseNom});

  factory SetupStatut.fromJson(Map<String, dynamic> json) => SetupStatut(
        installationTerminee: json['installation_terminee'] as bool,
        entrepriseNom: json['entreprise_nom'] as String?,
      );
}
