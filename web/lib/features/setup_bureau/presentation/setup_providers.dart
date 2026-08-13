import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../data/setup_repository.dart';
import '../domain/setup_statut.dart';

/// En dehors du binaire desktop bundlé (web navigateur, `flutter test`),
/// LOCAL_MODE est toujours false côté serveur — `/setup/statut` y
/// répondrait de toute façon 400. On l'évite complètement ici plutôt que de
/// dépendre d'un appel réseau garanti en échec à chaque démarrage de l'app
/// (voir aussi setup.py::_require_local_mode et Env.isDesktopBureau).
final setupStatutProvider = FutureProvider<SetupStatut>((ref) async {
  if (!Env.isDesktopBureau) {
    return const SetupStatut(installationTerminee: true);
  }
  return ref.watch(setupRepositoryProvider).fetchStatut();
});
