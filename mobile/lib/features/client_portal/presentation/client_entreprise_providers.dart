import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../entreprise/domain/entreprise_profil.dart';
import '../data/client_entreprise_repository.dart';
import '../domain/entreprise_liee.dart';

final clientEntrepriseProfilProvider = FutureProvider<EntrepriseProfil>((ref) {
  return ref.watch(clientEntrepriseRepositoryProvider).getProfil();
});

/// Autres entreprises liées au même compte Client (même email) — alimente le
/// sélecteur d'entreprise du drawer quand il y en a plusieurs.
final clientEntreprisesLieesProvider = FutureProvider<List<EntrepriseLiee>>((ref) {
  return ref.watch(clientEntrepriseRepositoryProvider).listEntreprisesLiees();
});
