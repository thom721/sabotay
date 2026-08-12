import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/async_state_views.dart';
import '../../../core/widgets/stat_card.dart';
import '../data/superadmin_repository.dart';
import '../domain/entreprise_summary.dart';
import '../domain/platform_statistiques.dart';
import 'platform_config_controller.dart';
import 'superadmin_auth_controller.dart';
import 'superadmin_scaffold.dart';

final _montantFormat = NumberFormat('#,##0.##');

/// Filtres de la liste des entreprises (recherche texte + statut
/// d'abonnement). Un record Dart offre une égalité structurelle gratuite,
/// ce qui en fait une clé de `FutureProvider.family` sûre : deux filtres
/// avec les mêmes valeurs partagent le même cache.
typedef EntrepriseFilter = ({String? q, String? statutAbonnement});

final superAdminEntreprisesProvider =
    FutureProvider.family<List<EntrepriseSummary>, EntrepriseFilter>((ref, filter) {
  return ref
      .watch(superAdminRepositoryProvider)
      .fetchEntreprises(q: filter.q, statutAbonnement: filter.statutAbonnement);
});

final superAdminStatistiquesProvider = FutureProvider<PlatformStatistiques>((ref) {
  return ref.watch(superAdminRepositoryProvider).getStatistiques();
});

const _statutFiltres = [
  (label: 'Tous', value: null),
  (label: 'Actif', value: 'actif'),
  (label: 'Essai', value: 'essai'),
  (label: 'Suspendu', value: 'suspendu'),
  (label: 'Annulé', value: 'annule'),
];

/// Liste de toutes les entreprises de la plateforme, réservée au
/// super-admin. Le routeur ne protège pas `/superadmin/*` (voir
/// `app_router.dart`) : c'est cet écran qui vérifie lui-même la session et
/// redirige vers la connexion super-admin si besoin.
class SuperAdminEntreprisesScreen extends ConsumerStatefulWidget {
  const SuperAdminEntreprisesScreen({super.key});

  @override
  ConsumerState<SuperAdminEntreprisesScreen> createState() =>
      _SuperAdminEntreprisesScreenState();
}

class _SuperAdminEntreprisesScreenState extends ConsumerState<SuperAdminEntreprisesScreen> {
  final _searchController = TextEditingController();
  String? _query;
  String? _statutAbonnement;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _submitSearch() {
    setState(() => _query = _searchController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(superAdminAuthControllerProvider);

    if (!authState.isLoading && authState.valueOrNull != true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/superadmin/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final filter = (q: _query, statutAbonnement: _statutAbonnement);
    final entreprisesAsync = ref.watch(superAdminEntreprisesProvider(filter));
    final statistiquesAsync = ref.watch(superAdminStatistiquesProvider);
    // Gardé "au chaud" pour que le dialog prix (_showEditMontantDialog) ait
    // déjà la valeur courante disponible via `ref.read` dès le premier clic.
    ref.watch(platformConfigControllerProvider);

    return SuperAdminScaffold(
      title: 'SabotayPro — Entreprises',
      actions: [
        IconButton(
          icon: const Icon(Icons.sell_outlined),
          tooltip: 'Prix abonnement',
          onPressed: () => _showEditMontantDialog(context, ref),
        ),
        IconButton(
          icon: const Icon(Icons.manage_accounts),
          tooltip: 'Comptes admin',
          onPressed: () => context.push('/superadmin/comptes'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          statistiquesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: ErrorState(
                message: 'Impossible de charger les statistiques',
                onRetry: () => ref.invalidate(superAdminStatistiquesProvider),
              ),
            ),
            data: (stats) => Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: _StatsGrid(stats: stats),
            ),
          ),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Rechercher une entreprise',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.arrow_forward),
                        tooltip: 'Rechercher',
                        onPressed: _submitSearch,
                      ),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _submitSearch(),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final statutFiltre in _statutFiltres)
                        ChoiceChip(
                          label: Text(statutFiltre.label),
                          selected: _statutAbonnement == statutFiltre.value,
                          onSelected: (_) =>
                              setState(() => _statutAbonnement = statutFiltre.value),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          entreprisesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => ErrorState(
              message: 'Impossible de charger les entreprises',
              onRetry: () => ref.invalidate(superAdminEntreprisesProvider(filter)),
            ),
            data: (entreprises) => entreprises.isEmpty
                ? const EmptyState(message: 'Aucune entreprise pour l\'instant')
                : Card(
                    margin: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < entreprises.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          _EntrepriseRow(entreprise: entreprises[i]),
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

/// Édition du prix d'abonnement (unique, global à toute la plateforme —
/// voir `platform_config_controller.dart`). Un simple dialog suffit pour un
/// seul champ, pas besoin du pattern bottom-sheet des autres formulaires.
Future<void> _showEditMontantDialog(BuildContext context, WidgetRef ref) async {
  final current = ref.read(platformConfigControllerProvider).valueOrNull;
  final montantController = TextEditingController(
    text: current?.abonnementMontantHtg.toString() ?? '',
  );
  final essaiController = TextEditingController(
    text: current?.essaiJours.toString() ?? '',
  );
  final formKey = GlobalKey<FormState>();
  var isSaving = false;

  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Abonnement'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: montantController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Montant (HTG)'),
                validator: (value) {
                  final parsed = int.tryParse(value ?? '');
                  if (parsed == null || parsed <= 0) return 'Montant invalide';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: essaiController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Durée de l'essai gratuit (jours)"),
                validator: (value) {
                  final parsed = int.tryParse(value ?? '');
                  if (parsed == null || parsed <= 0) return 'Nombre de jours invalide';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: isSaving ? null : () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: isSaving
                ? null
                : () async {
                    if (!formKey.currentState!.validate()) return;
                    setState(() => isSaving = true);
                    try {
                      await ref.read(platformConfigControllerProvider.notifier).updateConfig(
                            montant: int.parse(montantController.text),
                            essaiJours: int.parse(essaiController.text),
                          );
                      if (context.mounted) Navigator.of(context).pop();
                    } catch (_) {
                      setState(() => isSaving = false);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Impossible de mettre à jour les réglages')),
                        );
                      }
                    }
                  },
            child: isSaving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Enregistrer'),
          ),
        ],
      ),
    ),
  );
}

class _StatsGrid extends StatelessWidget {
  final PlatformStatistiques stats;

  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 860 ? 3 : (constraints.maxWidth > 560 ? 2 : 1);
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: columns == 1 ? 2.6 : 1.5,
          children: [
            StatCard(
              icon: Icons.storefront_outlined,
              label: 'Entreprises',
              value: stats.nbEntreprisesTotal.toString(),
            ),
            StatCard(
              icon: Icons.verified_outlined,
              label: 'Abonnements actifs',
              value: stats.nbEntreprisesAbonnementActif.toString(),
            ),
            StatCard(
              icon: Icons.groups_outlined,
              label: 'Clients (total)',
              value: stats.nbClientsTotal.toString(),
            ),
            StatCard(
              icon: Icons.badge_outlined,
              label: 'Employés (total)',
              value: stats.nbEmployesTotal.toString(),
            ),
            StatCard(
              icon: Icons.payments_outlined,
              label: 'Collecté par les entreprises',
              value: '${_montantFormat.format(stats.montantTotalCollecte)} HTG',
            ),
            StatCard(
              icon: Icons.receipt_long_outlined,
              label: 'Revenu abonnements',
              value: '${_montantFormat.format(stats.montantAbonnementsCollecte)} HTG',
            ),
          ],
        );
      },
    );
  }
}

class _EntrepriseRow extends StatelessWidget {
  final EntrepriseSummary entreprise;

  const _EntrepriseRow({required this.entreprise});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(entreprise.nom),
      subtitle: Text(
        '${entreprise.devise} · ${entreprise.nbEmployes} employé(s) · '
        '${entreprise.nbClients} client(s) · créée le ${entreprise.dateCreation}',
      ),
      trailing: entreprise.abonnement != null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AbonnementStatutChip(statut: entreprise.abonnement!.statut),
                if (entreprise.abonnement!.dateRenouvellement != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Renouvellement : ${entreprise.abonnement!.dateRenouvellement}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            )
          : const Chip(label: Text('Aucun abonnement')),
      onTap: () => context.push('/superadmin/entreprises/${entreprise.id}'),
    );
  }
}
