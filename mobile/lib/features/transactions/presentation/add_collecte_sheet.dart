import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../comptes/domain/compte_sabotay.dart';
import '../../comptes/presentation/compte_providers.dart';
import '../data/transaction_repository.dart';
import '../domain/collecte_result.dart';
import '../domain/transaction.dart';
import 'recu_pdf.dart';
import 'transaction_providers.dart';

final _confirmDateFormat = DateFormat('dd/MM/yyyy');
final _confirmAmountFormat = NumberFormat.decimalPattern('fr');

Future<void> showAddCollecteSheet(
  BuildContext context,
  CompteSabotay compte, {
  String? clientNom,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => _AddCollecteSheet(compte: compte, clientNom: clientNom),
  );
}

/// Enregistrement d'une collecte : le montant n'est jamais saisi librement —
/// l'agent choisit un nombre de jours (un paiement peut couvrir plusieurs
/// jours manqués d'un coup) et le montant est calculé automatiquement
/// (nb_jours * montant journalier). Trois étapes de confirmation distinctes
/// avant l'envoi, pour réduire le risque d'erreur sur une opération
/// financière irréversible sur le terrain.
class _AddCollecteSheet extends ConsumerStatefulWidget {
  final CompteSabotay compte;
  final String? clientNom;

  const _AddCollecteSheet({required this.compte, this.clientNom});

  @override
  ConsumerState<_AddCollecteSheet> createState() => _AddCollecteSheetState();
}

class _AddCollecteSheetState extends ConsumerState<_AddCollecteSheet> {
  static const _maxJours = 31;

  int _step = 0;
  int _nbJours = 1;
  DateTime _date = DateTime.now();
  bool _isSaving = false;
  Transaction? _transactionEnregistree;
  CollecteQueued? _collecteEnAttente;

  num get _montant => widget.compte.montantJournalier * _nbJours;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final result = await ref.read(transactionRepositoryProvider).create(
            compteId: widget.compte.id,
            date: _date,
            nbJours: _nbJours,
            montant: _montant,
          );
      if (result is CollecteSuccess) {
        ref.invalidate(compteSoldeProvider(widget.compte.id));
        ref.invalidate(transactionsForCompteProvider(widget.compte.id));
      }
      if (mounted) {
        // On garde la feuille ouverte pour proposer l'impression du reçu
        // (ou afficher l'état "en attente") : une fois fermée, le context
        // de la feuille n'est plus valable pour afficher une éventuelle
        // erreur d'impression.
        setState(() {
          _isSaving = false;
          switch (result) {
            case CollecteSuccess(:final transaction):
              _transactionEnregistree = transaction;
            case CollecteQueued():
              _collecteEnAttente = result;
          }
        });
      }
    } on SubscriptionRequiredException {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
            "Abonnement SaaS expiré : la collecte de fonds est bloquée. "
            "Contactez votre administrateur.",
          ),
        ));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'enregistrer la collecte')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final transaction = _transactionEnregistree;
    final collecteEnAttente = _collecteEnAttente;
    final soldeAsync = ref.watch(compteSoldeProvider(widget.compte.id));

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: transaction != null
          ? _CollecteEnregistreeView(
              transaction: transaction,
              compte: widget.compte,
              clientNom: widget.clientNom ?? '',
            )
          : collecteEnAttente != null
              ? _CollecteEnQueueView(resultat: collecteEnAttente)
              : switch (_step) {
              0 => _FormulaireStep(
                  compte: widget.compte,
                  nbJours: _nbJours,
                  maxJours: _maxJours,
                  date: _date,
                  soldeAsync: soldeAsync,
                  onNbJoursChanged: (v) => setState(() => _nbJours = v),
                  onPickDate: _pickDate,
                  onSuivant: () => setState(() => _step = 1),
                ),
              1 => _ConfirmationStep(
                  titre: 'Vérifier le client',
                  etape: 1,
                  rows: [
                    if (widget.clientNom != null) _ConfirmRow('Client', widget.clientNom!),
                    _ConfirmRow('N° de compte', widget.compte.numeroCompte),
                  ],
                  onRetour: () => setState(() => _step = 0),
                  onSuivant: () => setState(() => _step = 2),
                ),
              2 => _ConfirmationStep(
                  titre: 'Vérifier le montant',
                  etape: 2,
                  rows: [
                    _ConfirmRow('Nombre de jours', '$_nbJours'),
                    _ConfirmRow('Montant', '${_confirmAmountFormat.format(_montant)} HTG'),
                    _ConfirmRow('Date', _confirmDateFormat.format(_date)),
                  ],
                  onRetour: () => setState(() => _step = 1),
                  onSuivant: () => setState(() => _step = 3),
                ),
              _ => _ConfirmationFinaleStep(
                  clientNom: widget.clientNom,
                  compte: widget.compte,
                  nbJours: _nbJours,
                  montant: _montant,
                  date: _date,
                  isSaving: _isSaving,
                  onRetour: () => setState(() => _step = 2),
                  onConfirmer: _save,
                ),
            },
    );
  }
}

class _FormulaireStep extends StatelessWidget {
  final CompteSabotay compte;
  final int nbJours;
  final int maxJours;
  final DateTime date;
  final AsyncValue<CompteSolde> soldeAsync;
  final ValueChanged<int> onNbJoursChanged;
  final VoidCallback onPickDate;
  final VoidCallback onSuivant;

  const _FormulaireStep({
    required this.compte,
    required this.nbJours,
    required this.maxJours,
    required this.date,
    required this.soldeAsync,
    required this.onNbJoursChanged,
    required this.onPickDate,
    required this.onSuivant,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final montant = compte.montantJournalier * nbJours;
    final joursManques = soldeAsync.valueOrNull?.joursManques ?? 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Enregistrer une collecte', style: Theme.of(context).textTheme.titleLarge),
        if (joursManques > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$joursManques jour(s) manqué(s) — choisissez le nombre de jours à payer '
              'pour les couvrir.',
              style: TextStyle(color: colorScheme.onErrorContainer, fontSize: 13),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text('Nombre de jours à payer', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.filledTonal(
              onPressed: nbJours > 1 ? () => onNbJoursChanged(nbJours - 1) : null,
              icon: const Icon(Icons.remove),
            ),
            SizedBox(
              width: 64,
              child: Text(
                '$nbJours',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            IconButton.filledTonal(
              onPressed: nbJours < maxJours ? () => onNbJoursChanged(nbJours + 1) : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Montant (calculé)', style: TextStyle(fontWeight: FontWeight.w600)),
              Text(
                '${_confirmAmountFormat.format(montant)} HTG',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Date'),
          subtitle: Text(_confirmDateFormat.format(date)),
          trailing: const Icon(Icons.calendar_today, size: 20),
          onTap: onPickDate,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: onSuivant,
          child: const Text('Suivant'),
        ),
      ],
    );
  }
}

class _ConfirmationStep extends StatelessWidget {
  final String titre;
  final int etape;
  final List<Widget> rows;
  final VoidCallback onRetour;
  final VoidCallback onSuivant;

  const _ConfirmationStep({
    required this.titre,
    required this.etape,
    required this.rows,
    required this.onRetour,
    required this.onSuivant,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Confirmation $etape/3', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(titre, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        ...rows,
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(onPressed: onRetour, child: const Text('Retour')),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(onPressed: onSuivant, child: const Text('Suivant')),
            ),
          ],
        ),
      ],
    );
  }
}

class _ConfirmationFinaleStep extends StatelessWidget {
  final String? clientNom;
  final CompteSabotay compte;
  final int nbJours;
  final num montant;
  final DateTime date;
  final bool isSaving;
  final VoidCallback onRetour;
  final VoidCallback onConfirmer;

  const _ConfirmationFinaleStep({
    required this.clientNom,
    required this.compte,
    required this.nbJours,
    required this.montant,
    required this.date,
    required this.isSaving,
    required this.onRetour,
    required this.onConfirmer,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Confirmation 3/3', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Text('Confirmation finale', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        if (clientNom != null) _ConfirmRow('Client', clientNom!),
        _ConfirmRow('N° de compte', compte.numeroCompte),
        _ConfirmRow('Jours payés', '$nbJours'),
        _ConfirmRow('Montant', '${_confirmAmountFormat.format(montant)} HTG'),
        _ConfirmRow('Date', _confirmDateFormat.format(date)),
        const SizedBox(height: 16),
        Text(
          'Je confirme avoir reçu ce montant en espèces du client.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: isSaving ? null : onRetour,
                child: const Text('Retour'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: isSaving ? null : onConfirmer,
                child: isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Confirmer et enregistrer'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CollecteEnregistreeView extends ConsumerWidget {
  final Transaction transaction;
  final CompteSabotay compte;
  final String clientNom;

  const _CollecteEnregistreeView({
    required this.transaction,
    required this.compte,
    required this.clientNom,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle, color: Theme.of(context).colorScheme.secondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Collecte enregistrée', style: Theme.of(context).textTheme.titleLarge),
            ),
          ],
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () => imprimerRecu(
            context,
            ref,
            transaction: transaction,
            compte: compte,
            clientNom: clientNom,
          ),
          icon: const Icon(Icons.print_outlined),
          label: const Text('Imprimer le reçu'),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Terminer'),
        ),
      ],
    );
  }
}

/// Collecte saisie mais pas encore confirmée par le serveur (réseau
/// indisponible au moment de l'envoi) — mise en file, sera rejouée
/// automatiquement dès que la connexion revient (voir
/// `offline_drain_controller.dart`). Volontairement distincte de
/// [_CollecteEnregistreeView] : pas de bouton d'impression de reçu, le
/// montant affiché n'est pas encore garanti par le serveur.
class _CollecteEnQueueView extends StatelessWidget {
  final CollecteQueued resultat;

  const _CollecteEnQueueView({required this.resultat});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.cloud_off, color: Colors.amber),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Collecte enregistrée localement',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Pas de connexion — sera synchronisée automatiquement dès que le '
          'réseau revient.',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _ConfirmRow('Jours payés', '${resultat.nbJours}'),
              _ConfirmRow('Montant', '${_confirmAmountFormat.format(resultat.montant)} HTG'),
              _ConfirmRow('Date', _confirmDateFormat.format(resultat.date)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Terminer'),
        ),
      ],
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  final String label;
  final String value;

  const _ConfirmRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
