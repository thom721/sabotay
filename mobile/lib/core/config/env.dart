class Env {
  Env._();

  /// URL de base de l'API FastAPI.
  ///
  /// Par défaut, le cloud de prod — un `flutter run -d <appareil physique>`
  /// (émulateur ou téléphone réel) sans --dart-define doit pouvoir joindre
  /// le serveur, ce qu'aucune adresse localhost/10.0.2.2 ne permet sur un
  /// appareil réel. Aucun job CI ne fournit --dart-define=API_BASE_URL pour
  /// le mobile (contrairement à CLOUD_URL pour le desktop, voir
  /// .github/workflows/build.yml), donc ce repli est le seul qui s'applique
  /// en pratique tant qu'un build n'est pas lancé explicitement en dev.
  ///
  /// Pour développer contre un backend local, passer explicitement :
  /// --dart-define=API_BASE_URL=http://10.0.2.2:9004/api/v1 (émulateur
  /// Android) ou http://<ip-lan-de-la-machine-de-dev>:9004/api/v1 (appareil
  /// physique, même réseau) — 9004 = SERVER_PORT par défaut du backend dev.
  static String get apiBaseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;

    return 'https://sabotay.infini-software.cloud/api/v1';
  }
}
