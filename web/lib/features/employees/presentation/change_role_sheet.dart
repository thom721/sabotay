import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/user.dart';
import '../domain/employee.dart';
import 'employee_list_controller.dart';

Future<void> showChangeRoleSheet(BuildContext context, Employee employee) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => _ChangeRoleSheet(employee: employee),
  );
}

class _ChangeRoleSheet extends ConsumerWidget {
  final Employee employee;
  const _ChangeRoleSheet({required this.employee});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rôle de ${employee.nom}', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Choisissez le nouveau rôle de cet employé.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            for (final role in RoleUtilisateur.values)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.badge_outlined),
                title: Text(roleLabel(role)),
                selected: employee.role == role,
                onTap: () => _changeRole(context, ref, role),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeRole(BuildContext context, WidgetRef ref, RoleUtilisateur role) async {
    if (role == employee.role) {
      Navigator.of(context).pop();
      return;
    }
    try {
      await ref.read(employeeListControllerProvider.notifier).changeRole(employee, role);
      if (context.mounted) Navigator.of(context).pop();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de changer le rôle de cet employé')),
        );
      }
    }
  }
}
