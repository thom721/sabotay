import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/change_password_sheet.dart';
import '../../clients/presentation/client_search_sheet.dart';
import '../../rapports/presentation/rapport_screen.dart';
import '../../transactions/presentation/quick_collecte_sheet.dart';

/// Accueil de l'Agent — une grille de gros boutons plutôt que d'atterrir
/// directement sur la liste de clients (jugée peu accueillante). Chaque
/// bouton réutilise un écran/flux déjà existant, rien n'est dupliqué.
class AccueilScreen extends ConsumerWidget {
  const AccueilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).valueOrNull;

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
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user != null)
              Text('Bienvenue, ${user.nom}', style: Theme.of(context).textTheme.titleMedium),
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
