import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_state_views.dart';
import '../../../core/widgets/dashboard_shell.dart';
import '../data/abonnement_repository.dart';
import '../domain/abonnement.dart';
import 'recu_abonnement_pdf.dart';

final _dateFormat = DateFormat('dd/MM/yyyy');
final _montantFormat = NumberFormat('#,##0.##');

/// Écran Abonnement (Admin) : statut du plan SabotayPro et paiement annuel
/// via MonCash. Le paiement en ligne débloque l'enregistrement des
/// cotisations ; la gestion des clients/employés reste disponible sans
/// abonnement actif.
class AbonnementScreen extends ConsumerWidget {
  const AbonnementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final abonnementAsync = ref.watch(abonnementProvider);

    return DashboardContent(
      title: 'Abonnement',
      backgroundColor: const Color(0xFFF0F2F5),
      child: abonnementAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.only(top: 80),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => ErrorState(
          message: 'Impossible de charger l\'abonnement',
          onRetry: () => ref.invalidate(abonnementProvider),
        ),
        data: (abonnement) => _AbonnementContent(abonnement: abonnement),
      ),
    );
  }
}

class _AbonnementContent extends ConsumerStatefulWidget {
  final Abonnement abonnement;
  const _AbonnementContent({required this.abonnement});

  @override
  ConsumerState<_AbonnementContent> createState() => _AbonnementContentState();
}

class _AbonnementContentState extends ConsumerState<_AbonnementContent> {
  bool _isPaying = false;
  bool _isVerifying = false;
  bool _isDeclaringEspeces = false;

  Future<void> _payer() async {
    setState(() => _isPaying = true);
    try {
      final redirectUrl = await ref.read(abonnementRepositoryProvider).payer();
      await launchUrl(Uri.parse(redirectUrl), webOnlyWindowName: '_blank');
    } on DioException catch (e) {
      if (!mounted) return;
      final message = e.response?.statusCode == 503
          ? 'Le paiement en ligne n\'est pas encore configuré. Contactez l\'administrateur système.'
          : 'Impossible de démarrer le paiement. Réessayez plus tard.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de démarrer le paiement. Réessayez plus tard.')),
      );
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  Future<void> _verifier() async {
    setState(() => _isVerifying = true);
    try {
      final result = await ref.read(abonnementRepositoryProvider).verifier();
      ref.invalidate(abonnementProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.paye
                ? 'Paiement confirmé !'
                : 'Paiement non trouvé pour l\'instant — réessayez dans quelques instants.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de vérifier le paiement. Réessayez plus tard.')),
      );
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _declarerEspeces() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déclarer un paiement en espèces ?'),
        content: const Text(
          'À utiliser uniquement si vous avez déjà remis le montant en '
          'espèces à un responsable SabotayPro. Un administrateur système '
          'devra confirmer cette déclaration avant que l\'abonnement ne '
          's\'active.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Déclarer'),
          ),
        ],
      ),
    );
    if (confirme != true) return;

    setState(() => _isDeclaringEspeces = true);
    try {
      await ref.read(abonnementRepositoryProvider).declarerPaiementEspeces();
      ref.invalidate(paiementsAbonnementProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Déclaration envoyée — en attente de confirmation par l\'administrateur système.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'envoyer la déclaration. Réessayez plus tard.')),
      );
    } finally {
      if (mounted) setState(() => _isDeclaringEspeces = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final abonnement = widget.abonnement;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatutCard(abonnement: abonnement),
        if (!abonnement.estActif) ...[
          const SizedBox(height: 24),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Le paiement en ligne (100 HTG/an, via MonCash) débloque l\'enregistrement '
                    'des cotisations. La création de clients et d\'employés reste disponible '
                    'sans limite.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isPaying ? null : _payer,
                        icon: _isPaying
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.payments_outlined, size: 18),
                        label: const Text('Payer avec MonCash'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _isVerifying ? null : _verifier,
                        icon: _isVerifying
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('J\'ai payé — Vérifier'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _isDeclaringEspeces ? null : _declarerEspeces,
                        icon: _isDeclaringEspeces
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.money_outlined, size: 18),
                        label: const Text('Payer en espèces'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text('Historique des paiements', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        const _HistoriquePaiements(),
      ],
    );
  }
}

class _HistoriquePaiements extends ConsumerWidget {
  const _HistoriquePaiements();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paiementsAsync = ref.watch(paiementsAbonnementProvider);

    return paiementsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => ErrorState(
        message: 'Impossible de charger l\'historique des paiements',
        onRetry: () => ref.invalidate(paiementsAbonnementProvider),
      ),
      data: (paiements) => paiements.isEmpty
          ? const EmptyState(message: 'Aucun paiement pour l\'instant')
          : Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < paiements.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${_montantFormat.format(paiements[i].montant)} HTG — '
                              '${_dateFormat.format(paiements[i].datePaiement)}'
                              ' (${paiements[i].methode == 'especes' ? 'Espèces' : 'MonCash'})',
                            ),
                          ),
                          if (paiements[i].statut != 'confirme')
                            _StatutChip(
                              label: paiements[i].statut == 'en_attente' ? 'En attente' : 'Rejeté',
                              color: paiements[i].statut == 'en_attente'
                                  ? Theme.of(context).colorScheme.tertiary
                                  : Theme.of(context).colorScheme.error,
                            ),
                        ],
                      ),
                      subtitle: paiements[i].payeParNom != null
                          ? Text(
                              paiements[i].statut == 'en_attente'
                                  ? 'Déclaré par ${paiements[i].payeParNom}'
                                  : 'Confirmé par ${paiements[i].payeParNom}',
                            )
                          : null,
                      trailing: paiements[i].statut == 'confirme'
                          ? IconButton(
                              icon: const Icon(Icons.print_outlined),
                              tooltip: 'Imprimer le reçu',
                              onPressed: () => imprimerRecuAbonnement(
                                context,
                                ref,
                                paiement: paiements[i],
                              ),
                            )
                          : null,
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _StatutCard extends StatelessWidget {
  final Abonnement abonnement;
  const _StatutCard({required this.abonnement});

  // Pas de couleur "warning" dédiée dans le thème (seulement
  // primary/secondary/tertiary/error) — tertiary sert d'accent ambré pour
  // le statut "essai", cohérent avec la palette générée par le thème.
  Color _statutColor(ColorScheme colorScheme) => switch (abonnement.statut) {
        'actif' => colorScheme.secondary,
        'essai' => colorScheme.tertiary,
        _ => colorScheme.error,
      };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = _statutColor(colorScheme);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Plan ${abonnement.plan}', style: Theme.of(context).textTheme.titleMedium),
                _StatutChip(label: statutAbonnementLabel(abonnement.statut), color: color),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${_montantFormat.format(abonnement.montant)} HTG / an',
              style: AppTheme.statNumberStyle(context, fontSize: 24),
            ),
            if (abonnement.dateRenouvellement != null) ...[
              const SizedBox(height: 8),
              Text(
                '${_montantFormat.format(abonnement.montantProchainRenouvellement)} HTG · '
                'Renouvellement : ${_dateFormat.format(abonnement.dateRenouvellement!)}',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ],
            if (abonnement.datePaiement != null) ...[
              const SizedBox(height: 4),
              Text(
                'Dernier paiement : ${_dateFormat.format(abonnement.datePaiement!)}',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
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
