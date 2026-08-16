import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/async_state_views.dart';
import '../../abonnement/domain/paiement_abonnement.dart';
import '../../abonnement/presentation/recu_abonnement_pdf.dart';
import '../../entreprise/domain/entreprise_profile.dart';
import '../data/superadmin_repository.dart';
import '../domain/entreprise_detail.dart';
import '../domain/entreprise_summary.dart';
import 'superadmin_auth_controller.dart';
import 'superadmin_scaffold.dart';

final superAdminEntrepriseDetailProvider =
    FutureProvider.family<EntrepriseDetail, String>((ref, id) {
  return ref.watch(superAdminRepositoryProvider).fetchEntrepriseDetail(id);
});

final superAdminEntreprisePaiementsProvider =
    FutureProvider.family<List<PaiementAbonnement>, String>((ref, id) {
  return ref.watch(superAdminRepositoryProvider).fetchEntreprisePaiements(id);
});

/// Fiche complète d'une entreprise pour le super-admin : informations
/// générales, abonnement, puis liste intégrale des utilisateurs et des
/// clients. Vue de diagnostic en lecture seule — pas d'édition ici.
class SuperAdminEntrepriseDetailScreen extends ConsumerStatefulWidget {
  final String entrepriseId;

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
        data: (detail) => _DetailContent(detail: detail, entrepriseId: widget.entrepriseId),
      ),
    );
  }
}

class _DetailContent extends ConsumerStatefulWidget {
  final EntrepriseDetail detail;
  final String entrepriseId;

  const _DetailContent({required this.detail, required this.entrepriseId});

  @override
  ConsumerState<_DetailContent> createState() => _DetailContentState();
}

class _DetailContentState extends ConsumerState<_DetailContent> {
  bool _isResetting = false;

  Future<void> _confirmerReinitialisation() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Réinitialiser l'installation bureau ?"),
        content: Text(
          "${widget.detail.summary.nom} devra refaire son installation bureau — un "
          "nouveau code d'installation sera généré. L'ancien poste continuera de "
          "fonctionner (jeton non révoqué) jusqu'à ce que quelqu'un l'installe à nouveau.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Réinitialiser'),
          ),
        ],
      ),
    );
    if (confirme != true) return;

    setState(() => _isResetting = true);
    try {
      await ref.read(superAdminRepositoryProvider).reinitialiserInstallation(widget.entrepriseId);
      ref.invalidate(superAdminEntrepriseDetailProvider(widget.entrepriseId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossible de réinitialiser l'installation")),
        );
      }
    } finally {
      if (mounted) setState(() => _isResetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.detail.summary;

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
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Chip(
                      avatar: Icon(
                        summary.estInstalle ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 18,
                      ),
                      label: Text(summary.estInstalle ? 'Bureau installé' : 'Bureau non installé'),
                    ),
                    if (summary.estInstalle)
                      OutlinedButton.icon(
                        onPressed: _isResetting ? null : _confirmerReinitialisation,
                        icon: _isResetting
                            ? const SizedBox(
                                height: 14,
                                width: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.restart_alt, size: 18),
                        label: const Text("Réinitialiser l'installation"),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('Utilisateurs (${widget.detail.utilisateurs.length})',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        widget.detail.utilisateurs.isEmpty
            ? const _CardEmptyState(message: 'Aucun utilisateur')
            : Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < widget.detail.utilisateurs.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      ListTile(
                        title: Text(
                          widget.detail.utilisateurs[i].prenom != null
                              ? '${widget.detail.utilisateurs[i].prenom} ${widget.detail.utilisateurs[i].nom}'
                              : widget.detail.utilisateurs[i].nom,
                        ),
                        subtitle: Text(
                          '${widget.detail.utilisateurs[i].role} · ${widget.detail.utilisateurs[i].statut}'
                          '${widget.detail.utilisateurs[i].email != null ? ' · ${widget.detail.utilisateurs[i].email}' : ''}',
                        ),
                        trailing: Text(
                          widget.detail.utilisateurs[i].derniereConnexion ?? 'Jamais connecté',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
        const SizedBox(height: 24),
        Text('Clients (${widget.detail.clients.length})',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        widget.detail.clients.isEmpty
            ? const _CardEmptyState(message: 'Aucun client')
            : Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < widget.detail.clients.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      ListTile(
                        title: Text('${widget.detail.clients[i].prenom} ${widget.detail.clients[i].nom}'),
                        subtitle: Text(
                          '${widget.detail.clients[i].telephone} · ${widget.detail.clients[i].statut}'
                          '${widget.detail.clients[i].email != null ? ' · ${widget.detail.clients[i].email}' : ''}',
                        ),
                        trailing: Text(
                          widget.detail.clients[i].derniereConnexion ?? 'Jamais connecté',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
        const SizedBox(height: 24),
        Text('Historique des paiements', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _HistoriquePaiements(entrepriseId: widget.entrepriseId, summary: summary),
      ],
    );
  }
}

final _dateFormat = DateFormat('dd/MM/yyyy');
final _montantFormat = NumberFormat('#,##0.##');

class _HistoriquePaiements extends ConsumerWidget {
  final String entrepriseId;
  final EntrepriseSummary summary;

  const _HistoriquePaiements({required this.entrepriseId, required this.summary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paiementsAsync = ref.watch(superAdminEntreprisePaiementsProvider(entrepriseId));

    return paiementsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => ErrorState(
        message: 'Impossible de charger l\'historique des paiements',
        onRetry: () => ref.invalidate(superAdminEntreprisePaiementsProvider(entrepriseId)),
      ),
      data: (paiements) => paiements.isEmpty
          ? const _CardEmptyState(message: 'Aucun paiement pour l\'instant')
          : Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < paiements.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _PaiementTile(
                      entrepriseId: entrepriseId,
                      paiement: paiements[i],
                      summary: summary,
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _PaiementTile extends ConsumerStatefulWidget {
  final String entrepriseId;
  final PaiementAbonnement paiement;
  final EntrepriseSummary summary;

  const _PaiementTile({
    required this.entrepriseId,
    required this.paiement,
    required this.summary,
  });

  @override
  ConsumerState<_PaiementTile> createState() => _PaiementTileState();
}

class _PaiementTileState extends ConsumerState<_PaiementTile> {
  bool _isProcessing = false;

  Future<void> _traiter(Future<void> Function() action) async {
    setState(() => _isProcessing = true);
    try {
      await action();
      ref.invalidate(superAdminEntreprisePaiementsProvider(widget.entrepriseId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Action impossible. Réessayez plus tard.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final paiement = widget.paiement;
    final methodeLabel = paiement.methode == 'especes' ? 'Espèces' : 'MonCash';

    return ListTile(
      title: Row(
        children: [
          Expanded(
            child: Text(
              '${_montantFormat.format(paiement.montant)} HTG — '
              '${_dateFormat.format(paiement.datePaiement)} ($methodeLabel)',
            ),
          ),
          if (paiement.statut != 'confirme')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (paiement.statut == 'en_attente'
                        ? Theme.of(context).colorScheme.tertiary
                        : Theme.of(context).colorScheme.error)
                    .withOpacity(0.14),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                paiement.statut == 'en_attente' ? 'En attente' : 'Rejeté',
                style: TextStyle(
                  color: paiement.statut == 'en_attente'
                      ? Theme.of(context).colorScheme.tertiary
                      : Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
      subtitle: paiement.payeParNom != null
          ? Text(
              paiement.statut == 'en_attente'
                  ? 'Déclaré par ${paiement.payeParNom}'
                  : 'Confirmé par ${paiement.payeParNom}',
            )
          : null,
      trailing: _isProcessing
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : paiement.statut == 'en_attente'
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Rejeter',
                      onPressed: () => _traiter(
                        () => ref
                            .read(superAdminRepositoryProvider)
                            .rejeterPaiement(paiement.id),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.check),
                      tooltip: 'Confirmer',
                      onPressed: () => _traiter(
                        () => ref
                            .read(superAdminRepositoryProvider)
                            .confirmerPaiement(paiement.id),
                      ),
                    ),
                  ],
                )
              : IconButton(
                  icon: const Icon(Icons.print_outlined),
                  tooltip: 'Imprimer le reçu',
                  onPressed: () => imprimerRecuAbonnement(
                    context,
                    ref,
                    paiement: paiement,
                    // Le super-admin n'a pas de jeton staff — pas d'accès à
                    // GET /entreprises/profil (voir recu_abonnement_pdf.dart).
                    // Profil minimal reconstruit depuis
                    // EntrepriseSuperAdminRead, seuls nom/devise sont
                    // garantis disponibles ici.
                    entreprise: EntrepriseProfile(
                      id: widget.summary.id,
                      nom: widget.summary.nom,
                      devise: widget.summary.devise,
                      adresse: null,
                      telephoneContact: null,
                      formatRecu: '80mm',
                      texteBasRecu: null,
                      logoData: null,
                      fraisRetrait: 0,
                      statut: widget.summary.statut,
                    ),
                  ),
                ),
    );
  }
}

/// [EmptyState] enveloppé dans une Card — chaque section de cette fiche doit
/// rester sur un fond blanc, y compris quand elle est vide (sinon le texte
/// "Aucun ..." flotte directement sur le fond gris de la page).
class _CardEmptyState extends StatelessWidget {
  final String message;
  const _CardEmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            message,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}
