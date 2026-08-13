import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/async_state_views.dart';
import '../../../core/widgets/pos_style_stat_card.dart';
import '../data/superadmin_repository.dart';
import '../domain/entreprise_summary.dart';
import '../domain/platform_statistiques.dart';
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

    return SuperAdminScaffold(
      title: 'SabotayPro — Entreprises',
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Paramètres',
          onPressed: () => context.push('/superadmin/parametres'),
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

class _StatsGrid extends StatelessWidget {
  final PlatformStatistiques stats;

  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Mêmes seuils/ratios que _ResponsiveGrid de pos_api
        // (core/responsive.dart : AppBreakpoints.xl=1100, .md=480) — sinon
        // les cartes gardent le même ratio mais paraissent bien plus hautes
        // ici, qui n'affiche que 3 colonnes max au lieu de 4.
        final columns = constraints.maxWidth >= 1100 ? 4 : (constraints.maxWidth >= 480 ? 2 : 1);
        final ratio = constraints.maxWidth >= 1100 ? 2.2 : (constraints.maxWidth >= 480 ? 2.0 : 3.2);
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: ratio,
          children: [
            PosStyleStatCard(
              icon: Icons.storefront_outlined,
              label: 'Entreprises',
              value: stats.nbEntreprisesTotal.toString(),
              color: const Color(0xFF0077C5),
            ),
            PosStyleStatCard(
              icon: Icons.verified_outlined,
              label: 'Abonnements actifs',
              value: stats.nbEntreprisesAbonnementActif.toString(),
              color: const Color(0xFF2CA01C),
            ),
            PosStyleStatCard(
              icon: Icons.groups_outlined,
              label: 'Clients (total)',
              value: stats.nbClientsTotal.toString(),
              color: const Color(0xFF3182CE),
            ),
            PosStyleStatCard(
              icon: Icons.badge_outlined,
              label: 'Employés (total)',
              value: stats.nbEmployesTotal.toString(),
              color: const Color(0xFFD69E2E),
            ),
            PosStyleStatCard(
              icon: Icons.payments_outlined,
              label: 'Collecté par les entreprises',
              value: '${_montantFormat.format(stats.montantTotalCollecte)} HTG',
              color: const Color(0xFF2CA01C),
            ),
            PosStyleStatCard(
              icon: Icons.receipt_long_outlined,
              label: 'Revenu abonnements',
              value: '${_montantFormat.format(stats.montantAbonnementsCollecte)} HTG',
              color: const Color(0xFF0077C5),
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
      leading: Tooltip(
        message: entreprise.estInstalle ? 'Bureau installé' : 'Bureau non installé',
        child: Icon(
          entreprise.estInstalle ? Icons.check_circle : Icons.radio_button_unchecked,
          color: entreprise.estInstalle
              ? Colors.green
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
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
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Renouvellement : ${entreprise.abonnement!.dateRenouvellement}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
                    ),
                  ),
              ],
            )
          : const Chip(label: Text('Aucun abonnement')),
      onTap: () => context.push('/superadmin/entreprises/${entreprise.id}'),
    );
  }
}
