import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/dashboard_shell.dart' show NavItem;
import 'client_auth_controller.dart';
import 'client_entreprise_providers.dart';

const _sidebarWidth = 232.0;
const _wideBreakpoint = 900.0;

const _navItems = [
  NavItem(icon: Icons.dashboard_outlined, label: 'Dashboard', route: '/client/accueil'),
  NavItem(icon: Icons.history, label: 'Historique', route: '/client/historique'),
  NavItem(icon: Icons.person_outline, label: 'Profil', route: '/client/profil'),
];

/// Coquille du portail Client sur le web : barre latérale fixe sur grand
/// écran (repliée en tiroir sous 900px), même convention que `DashboardShell`
/// (espace staff), mais scopée à l'identité Client (`clientAuthControllerProvider`)
/// — inclut le sélecteur d'entreprise liée, absent côté staff.
class ClientPortalShell extends ConsumerWidget {
  final String title;
  final String currentRoute;
  final Widget child;

  const ClientPortalShell({
    super.key,
    required this.title,
    required this.currentRoute,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideBreakpoint;
        final sidebar = _Sidebar(currentRoute: currentRoute);

        return Scaffold(
          appBar: isWide ? null : AppBar(title: Text(title)),
          drawer: isWide ? null : Drawer(child: sidebar),
          body: Row(
            children: [
              if (isWide) SizedBox(width: _sidebarWidth, child: sidebar),
              if (isWide)
                VerticalDivider(width: 1, color: Theme.of(context).colorScheme.outline),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isWide) _PageHeader(title: title),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                        child: child,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PageHeader extends StatelessWidget {
  final String title;

  const _PageHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outline)),
      ),
      child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  final String currentRoute;

  const _Sidebar({required this.currentRoute});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final client = ref.watch(clientAuthControllerProvider).valueOrNull;

    return Container(
      color: colorScheme.surfaceVariant,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SabotayPro', style: Theme.of(context).textTheme.titleLarge),
                  Text(
                    'Espace Client',
                    style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                  ),
                  const _EntrepriseActiveLabel(),
                ],
              ),
            ),
            const _EntrepriseSelecteur(),
            for (final item in _navItems)
              _NavTile(item: item, selected: item.route == currentRoute),
            const Spacer(),
            if (client != null) _ClientTile(nomComplet: client.nomComplet),
          ],
        ),
      ),
    );
  }
}

/// Nom de l'entreprise actuellement active — seul indice visuel permettant
/// de confirmer qu'un changement d'entreprise (`_EntrepriseSelecteur`) a
/// bien eu lieu, en plus des comptes/soldes qui changent sur le dashboard.
class _EntrepriseActiveLabel extends ConsumerWidget {
  const _EntrepriseActiveLabel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entreprise = ref.watch(clientEntrepriseProfilProvider).valueOrNull;
    if (entreprise == null) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(Icons.storefront_outlined, size: 14, color: colorScheme.primary),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              entreprise.nom,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sélecteur d'entreprise — visible seulement quand le même email Client
/// est lié à plusieurs entreprises (voir `client_auth_controller.dart`
/// `switchEntreprise`).
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
            decoration: const InputDecoration(labelText: 'Entreprise', isDense: true),
            items: [
              for (final entreprise in entreprises)
                DropdownMenuItem(
                  value: entreprise.clientId,
                  child: Text(entreprise.entrepriseNom, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (clientId) {
              if (clientId == null || clientId == actif.clientId) return;
              ref.read(clientAuthControllerProvider.notifier).switchEntreprise(clientId);
            },
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _NavTile extends StatelessWidget {
  final NavItem item;
  final bool selected;

  const _NavTile({required this.item, required this.selected});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? colorScheme.primary.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => context.go(item.route),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Text(
                  item.label,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected ? colorScheme.primary : colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClientTile extends ConsumerWidget {
  final String nomComplet;

  const _ClientTile({required this.nomComplet});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colorScheme.outline)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: colorScheme.primary,
            child: Text(
              nomComplet.isNotEmpty ? nomComplet[0].toUpperCase() : '?',
              style: TextStyle(color: colorScheme.onPrimary, fontSize: 13),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              nomComplet,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 18),
            tooltip: 'Déconnexion',
            onPressed: () => ref.read(clientAuthControllerProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}
