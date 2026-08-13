import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/comptes/presentation/compte_providers.dart';
import '../../features/transactions/presentation/transaction_providers.dart';
import 'api_client.dart';
import 'offline_queue_service.dart';

/// Nombre d'opérations hors-ligne en attente — source du badge sur
/// l'accueil, mis à jour en direct (pas de polling côté UI).
final pendingCollecteCountProvider = StreamProvider<int>((ref) async* {
  yield await OfflineQueueService.instance.pendingCount();
  yield* OfflineQueueService.instance.pendingCountChanges;
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
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
