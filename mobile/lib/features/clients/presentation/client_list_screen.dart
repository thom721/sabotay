import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../rapports/presentation/rapport_screen.dart';
import '../../transactions/presentation/quick_collecte_sheet.dart';
import '../domain/client.dart';
import 'client_detail_screen.dart';
import 'client_list_controller.dart';

/// Liste complète de clients, partagée par les trois rôles — le contenu
/// varie automatiquement selon le filtrage déjà appliqué côté backend
/// (l'agent ne voit que ses clients assignés, Admin/Manager voient tout).
/// Accueil réel : `accueil_screen.dart` — ce lien "Voir tous mes clients"
/// depuis `client_search_sheet.dart` (le bouton "Rechercher un client" de
/// l'accueil) sert de repli pour parcourir librement plutôt que rechercher.
/// Le FAB "+" ouvre la collecte rapide par numéro de compte
/// (`quick_collecte_sheet.dart`) : c'est le seul point d'entrée de la
/// collecte, pour éviter les erreurs de sélection client/compte. L'app
/// mobile est un outil de collecte pur — créer/modifier un client ou un
/// employé n'est possible que depuis le web.
class ClientListScreen extends ConsumerWidget {
  const ClientListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsAsync = ref.watch(clientListControllerProvider);
    final user = ref.watch(authControllerProvider).valueOrNull;
    final isAgent = user?.role == RoleUtilisateur.agent;

    return Scaffold(
      appBar: AppBar(
        title: Text(isAgent ? 'Mes clients' : 'Clients'),
        actions: [
          IconButton(
            icon: const Icon(Icons.summarize_outlined),
            tooltip: 'Rapport de collecte',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RapportScreen()),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (value) {
              if (value == 'logout') {
                ref.read(authControllerProvider.notifier).logout();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Text(
                  user != null ? '${user.nom} · ${roleLabel(user.role)}' : '',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'logout', child: Text('Déconnexion')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(clientListControllerProvider.notifier).refresh(),
        child: clientsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            children: [
              const SizedBox(height: 120),
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 8),
              const Center(child: Text('Impossible de charger les clients')),
              Center(
                child: TextButton(
                  onPressed: () => ref.read(clientListControllerProvider.notifier).refresh(),
                  child: const Text('Réessayer'),
                ),
              ),
            ],
          ),
          data: (clients) => clients.isEmpty
              ? ListView(
                  children: [
                    const SizedBox(height: 120),
                    if (user != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Bienvenue, ${user.nom}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    const SizedBox(height: 16),
                    const Center(child: Text('Aucun client pour l\'instant')),
                  ],
                )
              : ListView.builder(
                  itemCount: clients.length,
                  itemBuilder: (context, index) => _ClientTile(client: clients[index]),
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showQuickCollecteSheet(context),
        tooltip: 'Collecte rapide',
        child: const Icon(Icons.add),
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
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ClientDetailScreen(client: client)),
        );
      },
    );
  }
}
