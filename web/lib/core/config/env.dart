import 'package:flutter/foundation.dart';

class Env {
  Env._();

  /// Vrai uniquement pour le binaire desktop bundlé (Epic 5), jamais pour le
  /// web navigateur ni pour `flutter test`. `kIsWeb` seul ne suffit pas :
  /// `flutter test` tourne sur la VM Dart, donc `kIsWeb == false` là aussi —
  /// mais `defaultTargetPlatform` y vaut `android` par défaut (comportement
  /// standard du test runner Flutter), jamais `windows`/`macos` réellement.
  static bool get isDesktopBureau {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  /// URL de base de l'API FastAPI. Le port 9004 correspond au
  /// `SERVER_PORT` par défaut du binaire desktop compilé (voir
  /// `backend/app/core/config.py`) — même convention que pos_api (leur
  /// défaut : 9003), un port distinct pour ne jamais entrer en conflit si
  /// les deux produits sont un jour installés sur le même poste.
  /// À terme, remplacer par --dart-define=API_BASE_URL=... pour la prod web.
  static String get apiBaseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;
    return 'http://127.0.0.1:9004/api/v1';
  }

  /// URL du cloud utilisée par l'assistant "Connecter au cloud" (Epic 5f,
  /// poste bureau uniquement) — fixe et non modifiable côté client (voir
  /// SetupBureauScreen), injectée à la compilation via
  /// --dart-define=CLOUD_URL=... par le CI (voir .github/workflows/build.yml),
  /// même mécanisme que apiBaseUrl ci-dessus. Repli codé en dur ici même
  /// sans --dart-define (même principe que pos_api : pas besoin de repasser
  /// l'URL à chaque build) — même domaine que le lien de synchronisation.
  static String get defaultCloudUrl {
    const override = String.fromEnvironment('CLOUD_URL');
    if (override.isNotEmpty) return override;
    return 'https://sabotay.infini-software.cloud';
  }
}
