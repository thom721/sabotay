import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/async_state_views.dart';
import '../../../core/widgets/dashboard_shell.dart';
import '../../auth/domain/user.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../domain/employee.dart';
import 'employee_list_controller.dart';

final _dateFormat = DateFormat('dd/MM/yyyy');
final _lastLoginFormat = DateFormat('dd/MM/yyyy HH:mm');

/// Recherche un employé par id dans la liste déjà chargée par
/// [employeeListControllerProvider] — il n'existe pas d'endpoint backend
/// `GET /utilisateurs/{id}` dédié, donc la fiche détail réutilise la liste.
Employee? _findEmployee(List<Employee> employees, String employeeId) {
  for (final employee in employees) {
    if (employee.id == employeeId) return employee;
  }
  return null;
}

/// Fiche détaillée d'un employé, en lecture seule (PRD §8.2).
class EmployeeDetailScreen extends ConsumerWidget {
  final String employeeId;
  const EmployeeDetailScreen({super.key, required this.employeeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeesAsync = ref.watch(employeeListControllerProvider);
    final employee = employeesAsync.valueOrNull == null
        ? null
        : _findEmployee(employeesAsync.valueOrNull!, employeeId);

    return DashboardShell(
      title: employee?.nomComplet ?? 'Employé',
      currentRoute: '/admin/employes',
      navItems: adminNavItems,
      child: employeesAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.only(top: 80),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => ErrorState(
          message: 'Impossible de charger l\'employé',
          onRetry: () => ref.read(employeeListControllerProvider.notifier).refresh(),
        ),
        data: (employees) {
          final found = _findEmployee(employees, employeeId);
          if (found == null) {
            return const EmptyState(message: 'Employé introuvable');
          }
          return _EmployeeInfoCard(employee: found);
        },
      ),
    );
  }
}

class _EmployeeInfoCard extends StatelessWidget {
  final Employee employee;
  const _EmployeeInfoCard({required this.employee});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final actif = employee.statut == StatutUtilisateur.actif;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: colorScheme.primary,
                  child: Text(
                    employee.prenom.isNotEmpty ? employee.prenom[0].toUpperCase() : '?',
                    style: TextStyle(color: colorScheme.onPrimary, fontSize: 18),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(employee.nomComplet, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(employee.telephone, style: TextStyle(color: colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                _StatutChip(
                  label: actif ? 'Actif' : 'Inactif',
                  color: actif ? colorScheme.secondary : colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            const Divider(height: 24),
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                _InfoField(label: 'Rôle', value: roleLabel(employee.role)),
                _InfoField(
                  label: 'Email',
                  value: (employee.email == null || employee.email!.isEmpty)
                      ? 'Non renseigné'
                      : employee.email!,
                ),
                _InfoField(
                  label: 'NIF/CIN',
                  value: (employee.nifCin == null || employee.nifCin!.isEmpty)
                      ? 'Non renseigné'
                      : employee.nifCin!,
                ),
                _InfoField(
                  label: 'Date de naissance',
                  value: employee.dateNaissance == null
                      ? 'Non renseignée'
                      : _dateFormat.format(employee.dateNaissance!),
                ),
                _InfoField(
                  label: 'Adresse',
                  value: (employee.adresse == null || employee.adresse!.isEmpty)
                      ? 'Non renseignée'
                      : employee.adresse!,
                ),
              ],
            ),
            const Divider(height: 24),
            _InfoField(
              label: 'Dernière connexion',
              value: employee.derniereConnexion == null
                  ? 'Jamais connecté'
                  : _lastLoginFormat.format(employee.derniereConnexion!),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoField extends StatelessWidget {
  final String label;
  final String value;
  const _InfoField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _StatutChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatutChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.4),
      ),
    );
  }
}
