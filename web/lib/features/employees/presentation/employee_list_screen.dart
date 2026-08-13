import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/async_state_views.dart';
import '../../../core/widgets/dashboard_shell.dart';
import '../../auth/domain/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../domain/employee.dart';
import 'change_role_sheet.dart';
import 'employee_list_controller.dart';
import 'invite_employee_sheet.dart';

final _lastLoginFormat = DateFormat('dd/MM/yyyy HH:mm');

/// Formatte la ligne de dernière connexion pour l'affichage, ex.
/// "Dernière connexion : 30/07/2026 14:05" ou "Jamais connecté".
String _formatDerniereConnexion(DateTime? derniereConnexion) {
  if (derniereConnexion == null) return 'Jamais connecté';
  return 'Dernière connexion : ${_lastLoginFormat.format(derniereConnexion)}';
}

/// Gestion des employés par l'Admin Entreprise (PRD §8.2, RBAC §6).
class EmployeeListScreen extends ConsumerWidget {
  const EmployeeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeesAsync = ref.watch(employeeListControllerProvider);

    return DashboardShell(
      title: 'Employés',
      currentRoute: '/admin/employes',
      navItems: adminNavItems,
      backgroundColor: const Color(0xFFF0F2F5),
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: () => ref.read(employeeListControllerProvider.notifier).refresh(),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => showInviteEmployeeSheet(context),
            icon: const Icon(Icons.person_add, size: 18),
            label: const Text('Inviter'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _RolesInfoPanel(),
          const SizedBox(height: 16),
          employeesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => ErrorState(
              message: 'Impossible de charger les employés',
              onRetry: () => ref.read(employeeListControllerProvider.notifier).refresh(),
            ),
            data: (employees) => employees.isEmpty
                ? const EmptyState(message: 'Aucun employé pour l\'instant')
                : Card(
                    margin: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < employees.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          _EmployeeTile(employee: employees[i]),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Panneau explicatif (dépliable) des permissions de chaque rôle, pour
/// aider l'Admin à choisir le bon rôle lors de l'invitation ou du
/// changement de rôle d'un employé (PRD RBAC §6).
class _RolesInfoPanel extends StatelessWidget {
  const _RolesInfoPanel();

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        leading: Icon(Icons.info_outline),
        title: Text('Rôles et permissions'),
        childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _RoleDescription(
            role: RoleUtilisateur.admin,
            description: 'Accès complet — gère les employés, les clients, les comptes '
                'Sabotay, les paramètres de l\'entreprise et l\'abonnement, et consulte '
                'tous les rapports.',
          ),
          SizedBox(height: 12),
          _RoleDescription(
            role: RoleUtilisateur.manager,
            description: 'Supervise une équipe ou une zone — gère les clients et les '
                'comptes Sabotay, valide les collectes, consulte les rapports de son '
                'équipe. Ne peut pas gérer les employés ni les paramètres de '
                'l\'entreprise.',
          ),
          SizedBox(height: 12),
          _RoleDescription(
            role: RoleUtilisateur.agent,
            description: 'Collecte sur le terrain — voit ses clients assignés, '
                'enregistre les cotisations quotidiennes, peut créer de nouveaux '
                'clients. Accès limité à ses propres clients et collectes.',
          ),
        ],
      ),
    );
  }
}

class _RoleDescription extends StatelessWidget {
  final RoleUtilisateur role;
  final String description;
  const _RoleDescription({required this.role, required this.description});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          roleLabel(role),
          style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary),
        ),
        const SizedBox(height: 2),
        Text(description, style: TextStyle(color: colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _EmployeeTile extends ConsumerWidget {
  final Employee employee;

  const _EmployeeTile({required this.employee});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isActif = employee.statut == StatutUtilisateur.actif;
    final isSelf = ref.watch(authControllerProvider).valueOrNull?.id == employee.id;

    return ListTile(
      onTap: () => context.push('/admin/employes/${employee.id}'),
      leading: CircleAvatar(
        backgroundColor: colorScheme.primary,
        child: Text(
          employee.prenom.isNotEmpty
              ? employee.prenom[0].toUpperCase()
              : (employee.nom.isNotEmpty ? employee.nom[0].toUpperCase() : '?'),
          style: TextStyle(color: colorScheme.onPrimary),
        ),
      ),
      title: Text(employee.nomComplet),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(employee.telephone),
          Text(
            _formatDerniereConnexion(employee.derniereConnexion),
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: isSelf ? 'Vous ne pouvez pas changer votre propre rôle' : 'Changer le rôle',
            child: TextButton.icon(
              onPressed: isSelf ? null : () => showChangeRoleSheet(context, employee),
              icon: const Icon(Icons.expand_more, size: 18),
              label: Text(roleLabel(employee.role)),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: isSelf ? 'Vous ne pouvez pas désactiver votre propre compte' : '',
            child: Switch(
              value: isActif,
              onChanged: isSelf
                  ? null
                  : (_) =>
                      ref.read(employeeListControllerProvider.notifier).toggleStatut(employee),
            ),
          ),
        ],
      ),
    );
  }
}
