import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/async_state_views.dart';
import '../data/superadmin_repository.dart';
import '../domain/entreprise_detail.dart';
import 'superadmin_auth_controller.dart';
import 'superadmin_scaffold.dart';

final superAdminEntrepriseDetailProvider =
    FutureProvider.family<EntrepriseDetail, int>((ref, id) {
  return ref.watch(superAdminRepositoryProvider).fetchEntrepriseDetail(id);
});

/// Fiche complète d'une entreprise pour le super-admin : informations
/// générales, abonnement, puis liste intégrale des utilisateurs et des
/// clients. Vue de diagnostic en lecture seule — pas d'édition ici.
class SuperAdminEntrepriseDetailScreen extends ConsumerStatefulWidget {
  final int entrepriseId;

  const SuperAdminEntrepriseDetailScreen({super.key, required this.entrepriseId});

  @override
  ConsumerState<SuperAdminEntrepriseDetailScreen> createState() =>
      _SuperAdminEntrepriseDetailScreenState();
}

class _SuperAdminEntrepriseDetailScreenState
    extends ConsumerState<SuperAdminEntrepriseDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(superAdminAuthControllerProvider);

    if (!authState.isLoading && authState.valueOrNull != true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/superadmin/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final detailAsync = ref.watch(superAdminEntrepriseDetailProvider(widget.entrepriseId));

    return SuperAdminScaffold(
      title: 'SabotayPro — Détail entreprise',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.go('/superadmin'),
      ),
      child: detailAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.only(top: 80),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => ErrorState(
          message: 'Impossible de charger cette entreprise',
          onRetry: () =>
              ref.invalidate(superAdminEntrepriseDetailProvider(widget.entrepriseId)),
        ),
        data: (detail) => _DetailContent(detail: detail),
      ),
    );
  }
}

class _DetailContent extends StatelessWidget {
  final EntrepriseDetail detail;

  const _DetailContent({required this.detail});

  @override
  Widget build(BuildContext context) {
    final summary = detail.summary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(summary.nom, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    Text('Devise : ${summary.devise}'),
                    Text('Statut : ${summary.statut}'),
                    Text('Créée le : ${summary.dateCreation}'),
                    Text('${summary.nbEmployes} employé(s)'),
                    Text('${summary.nbClients} client(s)'),
                  ],
                ),
                const SizedBox(height: 12),
                if (summary.abonnement != null)
                  Wrap(
                    spacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      AbonnementStatutChip(statut: summary.abonnement!.statut),
                      if (summary.abonnement!.dateRenouvellement != null)
                        Text('Renouvellement : ${summary.abonnement!.dateRenouvellement}'),
                      if (summary.abonnement!.montant != null)
                        Text('Montant : ${summary.abonnement!.montant} ${summary.devise}'),
                    ],
                  )
                else
                  const Chip(label: Text('Aucun abonnement')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('Utilisateurs (${detail.utilisateurs.length})',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        detail.utilisateurs.isEmpty
            ? const EmptyState(message: 'Aucun utilisateur')
            : Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < detail.utilisateurs.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      ListTile(
                        title: Text('${detail.utilisateurs[i].prenom} ${detail.utilisateurs[i].nom}'),
                        subtitle: Text(
                          '${detail.utilisateurs[i].role} · ${detail.utilisateurs[i].statut}'
                          '${detail.utilisateurs[i].email != null ? ' · ${detail.utilisateurs[i].email}' : ''}',
                        ),
                        trailing: Text(
                          detail.utilisateurs[i].derniereConnexion ?? 'Jamais connecté',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
        const SizedBox(height: 24),
        Text('Clients (${detail.clients.length})',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        detail.clients.isEmpty
            ? const EmptyState(message: 'Aucun client')
            : Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < detail.clients.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      ListTile(
                        title: Text('${detail.clients[i].prenom} ${detail.clients[i].nom}'),
                        subtitle: Text(
                          '${detail.clients[i].telephone} · ${detail.clients[i].statut}'
                          '${detail.clients[i].email != null ? ' · ${detail.clients[i].email}' : ''}',
                        ),
                        trailing: Text(
                          detail.clients[i].derniereConnexion ?? 'Jamais connecté',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ],
    );
  }
}
