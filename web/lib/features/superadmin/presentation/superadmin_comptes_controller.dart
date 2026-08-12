import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/superadmin_repository.dart';
import '../domain/superadmin_compte.dart';

final superAdminComptesControllerProvider =
    AsyncNotifierProvider<SuperAdminComptesController, List<SuperAdminCompte>>(
  SuperAdminComptesController.new,
);

class SuperAdminComptesController extends AsyncNotifier<List<SuperAdminCompte>> {
  @override
  Future<List<SuperAdminCompte>> build() =>
      ref.watch(superAdminRepositoryProvider).fetchComptes();

  Future<void> refresh() async {
    state = const AsyncLoading<List<SuperAdminCompte>>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => ref.read(superAdminRepositoryProvider).fetchComptes());
  }

  Future<void> create({required String nom, required String email, required String password}) async {
    await ref.read(superAdminRepositoryProvider).createCompte(
          nom: nom,
          email: email,
          password: password,
        );
    await refresh();
  }

  Future<void> toggleStatut(SuperAdminCompte compte) async {
    final nouveauStatut = compte.statut == 'actif' ? 'inactif' : 'actif';
    await ref.read(superAdminRepositoryProvider).updateCompteStatut(compte.id, nouveauStatut);
    await refresh();
  }
}
