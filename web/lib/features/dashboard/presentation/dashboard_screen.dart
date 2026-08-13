import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/dashboard_shell.dart';
import '../../../core/widgets/pos_style_stat_card.dart';
import '../../../core/widgets/stat_card.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../clients/domain/client.dart';
import '../../clients/presentation/client_list_controller.dart';
import '../../employees/domain/employee.dart';
import '../../employees/presentation/employee_list_controller.dart';

const adminNavItems = [
  NavItem(icon: Icons.space_dashboard_outlined, label: 'Tableau de bord', route: '/admin'),
  NavItem(icon: Icons.groups_outlined, label: 'Clients', route: '/admin/clients'),
  NavItem(icon: Icons.badge_outlined, label: 'Employés', route: '/admin/employes'),
  NavItem(icon: Icons.storefront_outlined, label: 'Entreprise', route: '/admin/entreprise'),
  NavItem(icon: Icons.receipt_long_outlined, label: 'Abonnement', route: '/admin/abonnement'),
];

const managerNavItems = [
  NavItem(icon: Icons.space_dashboard_outlined, label: 'Tableau de bord', route: '/manager'),
];

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    final clients = ref.watch(clientListControllerProvider).valueOrNull;
    final employees = ref.watch(employeeListControllerProvider).valueOrNull;

    final clientsActifs = clients?.where((c) => c.statut == StatutClient.actif).length;
    final agentsActifs = employees
        ?.where((e) => e.role.name == 'agent' && e.statut == StatutUtilisateur.actif)
        .length;

    return DashboardShell(
      title: 'Tableau de bord',
      currentRoute: '/admin',
      navItems: adminNavItems,
      // Même fond que le dashboard pos_api (AppColors.background) — voir
      // aussi SuperAdminScaffold, qui applique la même chose côté superadmin.
      backgroundColor: const Color(0xFFF0F2F5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                'Bienvenue, ${user.nom}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              // Mêmes seuils/ratios que _ResponsiveGrid de pos_api
              // (core/responsive.dart : AppBreakpoints.xl=1100, .md=480).
              final columns =
                  constraints.maxWidth >= 1100 ? 4 : (constraints.maxWidth >= 480 ? 2 : 1);
              final ratio =
                  constraints.maxWidth >= 1100 ? 2.2 : (constraints.maxWidth >= 480 ? 2.0 : 3.2);
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: ratio,
                children: [
                  const PosStyleStatCard(
                    icon: Icons.payments_outlined,
                    label: 'Total collecté (mois)',
                    value: '—',
                    color: Color(0xFF0077C5),
                  ),
                  PosStyleStatCard(
                    icon: Icons.groups_outlined,
                    label: 'Clients actifs',
                    value: clientsActifs?.toString() ?? '—',
                    color: const Color(0xFF3182CE),
                  ),
                  const PosStyleStatCard(
                    icon: Icons.warning_amber_outlined,
                    label: 'Taux de retard',
                    value: '—',
                    color: Color(0xFFD69E2E),
                  ),
                  PosStyleStatCard(
                    icon: Icons.badge_outlined,
                    label: 'Agents actifs',
                    value: agentsActifs?.toString() ?? '—',
                    color: const Color(0xFF2CA01C),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Le total collecté et le taux de retard nécessitent les rapports financiers '
            '(à venir) — les autres chiffres sont en direct.',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class ManagerDashboardScreen extends ConsumerWidget {
  const ManagerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).valueOrNull;

    return DashboardShell(
      title: 'Tableau de bord',
      currentRoute: '/manager',
      navItems: managerNavItems,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                'Bienvenue, ${user.nom}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 860 ? 3 : (constraints.maxWidth > 560 ? 2 : 1);
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: columns == 1 ? 2.6 : 1.5,
                children: const [
                  StatCard(icon: Icons.map_outlined, label: 'Ma zone', value: '—'),
                  StatCard(
                    icon: Icons.fact_check_outlined,
                    label: 'Retards à valider',
                    value: '—',
                  ),
                  StatCard(
                    icon: Icons.groups_outlined,
                    label: 'Clients de mon équipe',
                    value: '—',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Les rapports filtrés par zone/équipe ne sont pas encore branchés.',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
