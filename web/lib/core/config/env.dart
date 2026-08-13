class Env {
  Env._();

  /// URL de base de l'API FastAPI.
  /// À terme, remplacer par --dart-define=API_BASE_URL=... pour la prod.
  static String get apiBaseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;
    return 'http://127.0.0.1:8001/api/v1';
  }

  /// URL du cloud utilisée par l'assistant "Connecter au cloud" (Epic 5f,
  /// poste bureau uniquement) — fixe et non modifiable côté client (voir
  /// SetupBureauScreen), injectée à la compilation via
  /// --dart-define=CLOUD_URL=... par le CI (voir .github/workflows/build.yml),
  /// même mécanisme que apiBaseUrl ci-dessus. La valeur de repli est un
  /// placeholder — à confirmer avec le domaine de production définitif avant
  /// toute installation réelle chez un client (voir aussi MyAppURL dans
  /// certificat/sabotaypro-desktop.iss).
  static String get defaultCloudUrl {
    const override = String.fromEnvironment('CLOUD_URL');
    if (override.isNotEmpty) return override;
    return 'https://sabotaypro.com';
  }
}
