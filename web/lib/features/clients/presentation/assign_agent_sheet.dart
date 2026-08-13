import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/user.dart';
import '../../employees/domain/employee.dart';
import '../../employees/presentation/employee_list_controller.dart';
import '../domain/client.dart';
import 'client_list_controller.dart';

Future<void> showAssignAgentSheet(BuildContext context, Client client) {
  return showDialog(
    context: context,
    builder: (context) => _AssignAgentSheet(client: client),
  );
}

class _AssignAgentSheet extends ConsumerWidget {
  final Client client;
  const _AssignAgentSheet({required this.client});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeesAsync = ref.watch(employeeListControllerProvider);

    return AlertDialog(
      title: Text('Assigner ${client.nomComplet}'),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      content: SizedBox(
        width: 560,
        // Hauteur bornée + scroll — une longue liste d'agents ne doit pas
        // pousser les actions (Annuler) hors de l'écran sur un petit
        // viewport.
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text(
              'Choisissez l\'agent qui collectera chez ce client.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            employeesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('Impossible de charger les agents'),
              ),
              data: (employees) {
                final agents = employees
                    .where((e) => e.role == RoleUtilisateur.agent && e.statut == StatutUtilisateur.actif)
                    .toList();
                if (agents.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('Aucun agent actif — invitez-en un depuis "Employés".'),
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.person_off_outlined),
                      title: const Text('Non assigné'),
                      selected: client.agentAssigneId == null,
                      onTap: () => _assign(context, ref, null),
                    ),
                    for (final agent in agents)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.person_outline),
                        title: Text(agent.nom),
                        subtitle: Text(agent.telephone),
                        selected: client.agentAssigneId == agent.id,
                        onTap: () => _assign(context, ref, agent.id),
                      ),
                  ],
                );
              },
            ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
      ],
    );
  }

  Future<void> _assign(BuildContext context, WidgetRef ref, String? agentId) async {
    try {
      await ref.read(clientListControllerProvider.notifier).assignAgent(client.id, agentId);
      if (context.mounted) Navigator.of(context).pop();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de réassigner ce client')),
        );
      }
    }
  }
}
