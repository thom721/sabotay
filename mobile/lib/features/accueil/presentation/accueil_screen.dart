import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/offline_drain_controller.dart';
import '../../../core/network/offline_queue_service.dart';
import '../../../core/widgets/licence_banner.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/change_password_sheet.dart';
import '../../clients/presentation/client_search_sheet.dart';
import '../../rapports/presentation/rapport_screen.dart';
import '../../transactions/presentation/quick_collecte_sheet.dart';

/// Accueil de l'Agent — une grille de gros boutons plutôt que d'atterrir
/// directement sur la liste de clients (jugée peu accueillante). Chaque
/// bouton réutilise un écran/flux déjà existant, rien n'est dupliqué.
class AccueilScreen extends ConsumerStatefulWidget {
  const AccueilScreen({super.key});

  @override
  ConsumerState<AccueilScreen> createState() => _AccueilScreenState();
}

class _AccueilScreenState extends ConsumerState<AccueilScreen> {
  StreamSubscription<OfflineQueueItem>? _droppedSub;

  @override
  void initState() {
    super.initState();
    // Une collecte abandonnée après plusieurs tentatives (ex. compte
    // désactivé entre-temps) ne doit jamais disparaître silencieusement —
    // l'agent doit être prévenu pour ressaisir manuellement au besoin.
    _droppedSub = OfflineQueueService.instance.dropped.listen((item) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Collecte non synchronisée'),
          content: const Text(
            'Une collecte enregistrée hors-ligne n\'a pas pu être envoyée au '
            'serveur après plusieurs tentatives. Vérifiez le compte concerné '
            'et ressaisissez la collecte si nécessaire.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Compris'),
            ),
          ],
        ),
      );
    });
  }

  @override
  void dispose() {
    _droppedSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    final pendingCount = ref.watch(pendingCollecteCountProvider).valueOrNull ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sabotaypro'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profil',
            onPressed: () => showChangePasswordSheet(context),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LicenceBanner(),
          if (pendingCount > 0) _CollectesEnAttenteBanner(count: pendingCount),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (user != null)
                    Text(
                      'Bienvenue, ${user.nom}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      children: [
                        _AccueilButton(
                          icon: Icons.person_search,
                          label: 'Rechercher un client',
                          onTap: () => showClientSearchSheet(context),
                        ),
                        _AccueilButton(
                          icon: Icons.add_circle_outline,
                          label: 'Collecter',
                          onTap: () => showQuickCollecteSheet(context),
                        ),
                        _AccueilButton(
                          icon: Icons.summarize_outlined,
                          label: 'Historique / Rapport',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const RapportScreen()),
                          ),
                        ),
                        _AccueilButton(
                          icon: Icons.logout,
                          label: 'Déconnexion',
                          onTap: () => ref.read(authControllerProvider.notifier).logout(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge indiquant des collectes saisies hors-ligne et pas encore
/// confirmées par le serveur (voir `offline_drain_controller.dart`).
class _CollectesEnAttenteBanner extends StatelessWidget {
  final int count;

  const _CollectesEnAttenteBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.amber.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 18, color: Colors.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              count == 1
                  ? '1 collecte en attente de synchronisation'
                  : '$count collectes en attente de synchronisation',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccueilButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AccueilButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceVariant.withOpacity(0.5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
