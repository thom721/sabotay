import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/user.dart';
import '../../features/auth/presentation/auth_controller.dart';
import 'licence_banner.dart';

class NavItem {
  final IconData icon;
  final String label;
  final String route;

  const NavItem({required this.icon, required this.label, required this.route});
}

const _sidebarWidth = 232.0;
const _wideBreakpoint = 900.0;

/// Coquille commune à tout l'espace connecté : navigation latérale fixe sur
/// grand écran (repliée en tiroir sous 900px), en-tête de page, et contenu
/// défilant. Utilisée par les trois tableaux de bord (Admin/Manager/Agent)
/// et les écrans de gestion (employés, clients) pour une identité cohérente.
class DashboardShell extends ConsumerWidget {
  final String title;
  final String currentRoute;
  final List<NavItem> navItems;
  final Widget child;
  final Widget? action;
  // Optionnel — laisse le fond du thème par défaut si non fourni, pour ne
  // pas changer l'apparence des écrans qui ne le demandent pas explicitement
  // (voir AdminDashboardScreen, seul écran à le passer pour l'instant).
  final Color? backgroundColor;

  const DashboardShell({
    super.key,
    required this.title,
    required this.currentRoute,
    required this.navItems,
    required this.child,
    this.action,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).valueOrNull;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideBreakpoint;
        final sidebar = _Sidebar(navItems: navItems, currentRoute: currentRoute, user: user);

        return Scaffold(
          backgroundColor: backgroundColor,
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
                    if (isWide) _PageHeader(title: title, action: action),
                    const LicenceBanner(),
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
  final Widget? action;

  const _PageHeader({required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outline)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  final List<NavItem> navItems;
  final String currentRoute;
  final User? user;

  const _Sidebar({required this.navItems, required this.currentRoute, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.surfaceVariant,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SabotayPro', style: Theme.of(context).textTheme.titleLarge),
                  Text(
                    'Konekte SA',
                    style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            for (final item in navItems)
              _NavTile(
                item: item,
                selected: item.route == currentRoute,
              ),
            const Spacer(),
            if (user != null) _UserTile(user: user!),
          ],
        ),
      ),
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

class _UserTile extends ConsumerWidget {
  final User user;

  const _UserTile({required this.user});

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
              user.nom.isNotEmpty ? user.nom[0].toUpperCase() : '?',
              style: TextStyle(color: colorScheme.onPrimary, fontSize: 13),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user.nom,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  roleLabel(user.role),
                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 18),
            tooltip: 'Déconnexion',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}
