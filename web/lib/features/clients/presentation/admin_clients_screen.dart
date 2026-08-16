import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/async_state_views.dart';
import '../../../core/widgets/dashboard_shell.dart';
import '../../employees/presentation/employee_list_controller.dart';
import '../domain/client.dart';
import 'add_client_sheet.dart';
import 'assign_agent_sheet.dart';
import 'client_list_controller.dart';

final _lastLoginFormat = DateFormat('dd/MM/yyyy HH:mm');

/// Formatte la ligne de dernière connexion pour l'affichage, ex.
/// "Dernière connexion : 30/07/2026 14:05" ou "Jamais connecté".
String _formatDerniereConnexion(DateTime? derniereConnexion) {
  if (derniereConnexion == null) return 'Jamais connecté';
  return 'Dernière connexion : ${_lastLoginFormat.format(derniereConnexion)}';
}

/// Gestion des clients par l'Admin/Manager (PRD §8.3) : vue d'ensemble de
/// tous les clients de l'entreprise, avec assignation à un agent.
class AdminClientsScreen extends ConsumerStatefulWidget {
  const AdminClientsScreen({super.key});

  @override
  ConsumerState<AdminClientsScreen> createState() => _AdminClientsScreenState();
}

class _AdminClientsScreenState extends ConsumerState<AdminClientsScreen> {
  final _rechercheController = TextEditingController();
  String _recherche = '';

  @override
  void dispose() {
    _rechercheController.dispose();
    super.dispose();
  }

  List<Client> _filtrer(List<Client> clients) {
    final q = _recherche.trim().toLowerCase();
    if (q.isEmpty) return clients;
    return clients
        .where((c) =>
            c.nomComplet.toLowerCase().contains(q) || c.telephone.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientListControllerProvider);
    final employeesAsync = ref.watch(employeeListControllerProvider);

    // Nom de l'agent assigné, résolu depuis la liste des employés déjà en
    // mémoire — évite un appel réseau par client.
    String agentName(String? agentId) {
      if (agentId == null) return 'Non assigné';
      final employee = employeesAsync.valueOrNull?.where((e) => e.id == agentId).firstOrNull;
      return employee?.nom ?? 'Non assigné';
    }

    return DashboardContent(
      title: 'Clients',
      backgroundColor: const Color(0xFFF0F2F5),
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
        data: (clients) {
          final filtres = _filtrer(clients);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 360,
                child: TextField(
                  controller: _rechercheController,
                  decoration: const InputDecoration(
                    hintText: 'Rechercher un client (nom, téléphone)',
                    prefixIcon: Icon(Icons.search, size: 20),
                    isDense: true,
                  ),
                  onChanged: (value) => setState(() => _recherche = value),
                ),
              ),
              const SizedBox(height: 16),
              if (clients.isEmpty)
                const EmptyState(message: 'Aucun client pour l\'instant')
              else if (filtres.isEmpty)
                const EmptyState(message: 'Aucun client ne correspond à cette recherche')
              else
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < filtres.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _ClientRow(
                          client: filtres[i],
                          agentName: agentName(filtres[i].agentAssigneId),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ClientRow extends StatelessWidget {
  final Client client;
  final String agentName;

  const _ClientRow({required this.client, required this.agentName});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final unassigned = client.agentAssigneId == null;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: colorScheme.primary,
        child: Text(
          client.prenom.isNotEmpty ? client.prenom[0].toUpperCase() : '?',
          style: TextStyle(color: colorScheme.onPrimary),
        ),
      ),
      title: Text(client.nomComplet),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(client.telephone),
          Text(
            _formatDerniereConnexion(client.derniereConnexion),
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
      onTap: () => context.push('/admin/clients/${client.id}'),
      trailing: TextButton.icon(
        onPressed: () => showAssignAgentSheet(context, client),
        icon: Icon(
          Icons.person_outline,
          size: 16,
          color: unassigned ? colorScheme.error : colorScheme.onSurfaceVariant,
        ),
        label: Text(
          agentName,
          style: TextStyle(color: unassigned ? colorScheme.error : colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
