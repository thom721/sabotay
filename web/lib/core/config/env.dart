class Env {
  Env._();

  /// URL de base de l'API FastAPI.
  /// À terme, remplacer par --dart-define=API_BASE_URL=... pour la prod.
  static String get apiBaseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;
    return 'http://127.0.0.1:8001/api/v1';
  }
}
