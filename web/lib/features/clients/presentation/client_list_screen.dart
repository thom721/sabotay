import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/async_state_views.dart';
import '../../../core/widgets/dashboard_shell.dart';
import '../domain/client.dart';
import 'add_client_sheet.dart';
import 'client_list_controller.dart';

const agentNavItems = [
  NavItem(icon: Icons.groups_outlined, label: 'Mes clients', route: '/agent'),
];

/// "Mes clients du jour" pour l'agent de collecte (PRD §7.3, §8.5).
class ClientListScreen extends ConsumerWidget {
  const ClientListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsAsync = ref.watch(clientListControllerProvider);

    return DashboardShell(
      title: 'Mes clients',
      currentRoute: '/agent',
      navItems: agentNavItems,
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: () => ref.read(clientListControllerProvider.notifier).refresh(),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => showAddClientSheet(context),
            icon: const Icon(Icons.person_add, size: 18),
            label: const Text('Ajouter un client'),
          ),
        ],
      ),
      child: clientsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.only(top: 80),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => ErrorState(
          message: 'Impossible de charger les clients',
          onRetry: () => ref.read(clientListControllerProvider.notifier).refresh(),
        ),
        data: (clients) => clients.isEmpty
            ? const EmptyState(message: 'Aucun client pour l\'instant')
            : Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < clients.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      _ClientTile(client: clients[i]),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _ClientTile extends StatelessWidget {
  final Client client;

  const _ClientTile({required this.client});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: colorScheme.primary,
        child: Text(
          client.prenom.isNotEmpty ? client.prenom[0].toUpperCase() : '?',
          style: TextStyle(color: colorScheme.onPrimary),
        ),
      ),
      title: Text(client.nomComplet),
      subtitle: Text(client.telephone),
      trailing: client.statut == StatutClient.inactif
          ? const Chip(label: Text('Inactif'))
          : const Icon(Icons.chevron_right),
      onTap: () {
        // TODO: écran de détail du client + comptes Sabotay / collecte.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Détail de ${client.nomComplet} — à venir')),
        );
      },
    );
  }
}

