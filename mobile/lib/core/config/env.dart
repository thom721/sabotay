import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

class Env {
  Env._();

  /// URL de base de l'API FastAPI.
  ///
  /// - Web : dart:io n'existe pas sur cette plateforme — `Platform.isAndroid`
  ///   lève une exception au runtime si on l'évalue, donc il faut sortir
  ///   avant d'y toucher (ordre des branches important ci-dessous).
  /// - Émulateur Android : 127.0.0.1 pointe vers l'émulateur lui-même,
  ///   il faut passer par l'alias 10.0.2.2 pour atteindre l'hôte.
  /// - iOS (simulateur ou appareil physique sur le même réseau) : 127.0.0.1
  ///   fonctionne pour le simulateur ; un appareil physique nécessite l'IP
  ///   réseau réelle de la machine de dev (à passer via --dart-define).
  /// À terme, remplacer par --dart-define=API_BASE_URL=... pour la prod.
  static String get apiBaseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;

    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8001/api/v1';
    }
    return 'http://127.0.0.1:8001/api/v1';
  }
}
