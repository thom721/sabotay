import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/clients/presentation/client_list_controller.dart';
import '../../features/comptes/presentation/compte_providers.dart';
import '../../features/entreprise/presentation/entreprise_providers.dart';
import '../../features/transactions/presentation/transaction_providers.dart';
import '../storage/local_db_service.dart';
import '../storage/offline_cache_service.dart';
import 'api_client.dart';
import 'offline_queue_service.dart';

/// Nombre d'opérations hors-ligne en attente — source du badge sur
/// l'accueil, mis à jour en direct (pas de polling côté UI).
final pendingCollecteCountProvider = StreamProvider<int>((ref) async* {
  yield await OfflineQueueService.instance.pendingCount();
  yield* OfflineQueueService.instance.pendingCountChanges;
});

/// Date de la synchro la plus ancienne parmi les 4 entités mises en cache
/// (Epic 6) — la moins fraîche des quatre, pour rester honnête sur l'état
/// réel des données affichées plutôt que de n'en montrer qu'une. `null` si
/// aucun cycle de sync n'a encore réussi (ex. tout premier lancement,
/// jamais eu de réseau). Invalidé par `OfflineDrainScope` à chaque cycle.
final derniereSynchroProvider = FutureProvider<DateTime?>((ref) async {
  final dates = await Future.wait([
    LocalDbService.instance.derniereSynchro('clients'),
    LocalDbService.instance.derniereSynchro('comptes'),
    LocalDbService.instance.derniereSynchro('transactions'),
    LocalDbService.instance.derniereSynchro('entreprise_profil'),
  ]);
  final connues = dates.whereType<DateTime>().toList();
  if (connues.isEmpty) return null;
  return connues.reduce((a, b) => a.isBefore(b) ? a : b);
});

/// Relance `OfflineQueueService.drain()` au retour au premier plan et
/// périodiquement tant qu'une session staff est active — en Phase 1 c'est
/// la seule façon dont une collecte mise en file finit par atteindre le
/// serveur (pas de push serveur→client, pas de WebSocket). À placer une
/// seule fois, au-dessus du `MaterialApp.router` (voir `main.dart`).
class OfflineDrainScope extends ConsumerStatefulWidget {
  final Widget child;

  const OfflineDrainScope({super.key, required this.child});

  @override
  ConsumerState<OfflineDrainScope> createState() => _OfflineDrainScopeState();
}

class _OfflineDrainScopeState extends ConsumerState<OfflineDrainScope>
    with WidgetsBindingObserver {
  static const _intervalle = Duration(minutes: 2);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(_intervalle, (_) => _drain());
    _drain();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _drain();
  }

  Future<void> _drain() async {
    final estConnecte = ref.read(authControllerProvider).valueOrNull != null;
    if (!estConnecte) return;

    final dio = ref.read(apiClientProvider);
    final rejouees = await OfflineQueueService.instance.drain(dio);
    if (rejouees > 0) {
      // On ne sait pas précisément quels comptes ont été touchés — la
      // volumétrie de collectes en attente par agent est faible, invalider
      // toute la famille est largement suffisant en Phase 1.
      ref.invalidate(transactionsForCompteProvider);
      ref.invalidate(compteSoldeProvider);
    }

    // Même déclencheurs que le drain ci-dessus (retour au premier plan,
    // timer, retour réseau) — rafraîchit le cache offline (Epic 6) pour
    // qu'un agent reparti sans réseau ait des données aussi fraîches que
    // possible.
    await OfflineCacheService.instance.syncAll(dio);
    ref.invalidate(clientListControllerProvider);
    ref.invalidate(comptesForClientProvider);
    ref.invalidate(compteSoldeProvider);
    ref.invalidate(transactionsForCompteProvider);
    ref.invalidate(entrepriseProfilProvider);
    ref.invalidate(derniereSynchroProvider);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
