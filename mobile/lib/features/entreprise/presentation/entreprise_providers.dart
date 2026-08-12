import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/entreprise_repository.dart';
import '../domain/entreprise_profil.dart';

/// Profil de l'entreprise du tenant courant — accessible aux 3 rôles côté
/// backend (`GET /entreprises/profil`), utilisé pour l'en-tête des reçus
/// imprimés (nom, adresse, format papier thermique, texte de pied de page).
final entrepriseProfilProvider = FutureProvider<EntrepriseProfil>((ref) {
  return ref.watch(entrepriseRepositoryProvider).getProfil();
});
