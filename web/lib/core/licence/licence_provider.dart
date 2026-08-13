import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import 'licence_verifier.dart';

/// Statut de licence de l'entreprise courante — vérifié Ed25519, avec repli
/// sur cache hors-ligne. Purement informatif en Phase 1 (le blocage réel
/// reste géré côté serveur via 402 sur POST /transactions).
final licenceStatusProvider = FutureProvider<LicenceStatus>((ref) {
  return LicenceVerifier.check(ref.watch(apiClientProvider));
});
