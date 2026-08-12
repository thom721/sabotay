import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../entreprise/domain/entreprise_profil.dart';
import 'client_auth_controller.dart';
import 'client_entreprise_providers.dart';

/// Volet de navigation partagé par les 3 écrans du portail Client : Dashboard,
/// Historique, Profil (PRD §8.8).
class ClientNavDrawer extends ConsumerWidget {
  const ClientNavDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(clientAuthControllerProvider).valueOrNull;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sabotaypro', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  if (client != null) ...[
                    const SizedBox(height: 4),
                    Text(client.nomComplet, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                  const _EntrepriseActiveLabel(),
                ],
              ),
            ),
            const _EntrepriseSelecteur(),
            _DrawerItem(
              icon: Icons.dashboard_outlined,
              label: 'Dashboard',
              onTap: () => _goTo(context, '/client/accueil'),
            ),
            _DrawerItem(
              icon: Icons.history,
              label: 'Historique',
              onTap: () => _goTo(context, '/client/historique'),
            ),
            _DrawerItem(
              icon: Icons.person_outline,
              label: 'Profil',
              onTap: () => _goTo(context, '/client/profil'),
            ),
            const Spacer(),
            _DrawerItem(
              icon: Icons.logout,
              label: 'Déconnexion',
              onTap: () {
                Navigator.of(context).pop();
                ref.read(clientAuthControllerProvider.notifier).logout();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _goTo(BuildContext context, String path) {
    // Passer par go_router (plutôt qu'un Navigator.push brut) pour que son
    // état interne reste synchronisé avec la pile réellement affichée — un
    // écart entre les deux provoquait une assertion dès que `redirect`
    // devait réconcilier la navigation (ex. après un changement d'entreprise).
    Navigator.of(context).pop();
    context.go(path);
  }
}

/// Nom de l'entreprise actuellement active — seul indice visuel permettant
/// de confirmer qu'un changement d'entreprise (`_EntrepriseSelecteur`) a
/// bien eu lieu, en plus des comptes/soldes qui changent sur le dashboard.
class _EntrepriseActiveLabel extends ConsumerWidget {
  const _EntrepriseActiveLabel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final EntrepriseProfil? entreprise =
        ref.watch(clientEntrepriseProfilProvider).valueOrNull;
    if (entreprise == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(Icons.storefront_outlined, size: 14, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            entreprise.nom,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

/// Sélecteur d'entreprise — visible seulement quand le même email Client
/// est lié à plusieurs entreprises (voir `client_auth_controller.dart`
/// `switchEntreprise`), même convention que `_CompteSelecteur` du dashboard
/// (`client_dashboard_screen.dart`) qui ne s'affiche que si `length > 1`.
class _EntrepriseSelecteur extends ConsumerWidget {
  const _EntrepriseSelecteur();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entreprisesAsync = ref.watch(clientEntreprisesLieesProvider);
    return entreprisesAsync.maybeWhen(
      data: (entreprises) {
        if (entreprises.length <= 1) return const SizedBox.shrink();
        final actif = entreprises.firstWhere(
          (e) => e.actif,
          orElse: () => entreprises.first,
        );
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: DropdownButtonFormField<int>(
            value: actif.clientId,
            decoration: const InputDecoration(labelText: 'Entreprise'),
            items: [
              for (final entreprise in entreprises)
                DropdownMenuItem(
                  value: entreprise.clientId,
                  child: Text(entreprise.entrepriseNom),
                ),
            ],
            onChanged: (clientId) {
              if (clientId == null || clientId == actif.clientId) return;
              Navigator.of(context).pop();
              ref.read(clientAuthControllerProvider.notifier).switchEntreprise(clientId);
            },
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerItem({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        onTap: onTap,
      ),
    );
  }
}
