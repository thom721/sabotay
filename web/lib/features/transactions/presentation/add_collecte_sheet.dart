import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../comptes/domain/compte_sabotay.dart';
import '../../comptes/presentation/compte_providers.dart';
import '../data/transaction_repository.dart';
import '../domain/transaction.dart';
import 'recu_pdf.dart';

final _dateFormat = DateFormat('dd/MM/yyyy');
final _amountFormat = NumberFormat.decimalPattern('fr');

/// Équivalent bureau/web de `add_collecte_sheet.dart` (mobile) — un seul
/// dialogue au lieu des 3 étapes de confirmation successives du mobile
/// (pensées pour réduire le risque de faux clic sur un petit écran tactile
/// en déplacement, moins pertinent ici) : une case à cocher explicite
/// suffit avant l'envoi.
Future<void> showAddCollecteSheet(
  BuildContext context,
  CompteSabotay compte, {
  String? clientNom,
}) {
  return showDialog(
    context: context,
    builder: (context) => _AddCollecteDialog(compte: compte, clientNom: clientNom),
  );
}

class _AddCollecteDialog extends ConsumerStatefulWidget {
  final CompteSabotay compte;
  final String? clientNom;

  const _AddCollecteDialog({required this.compte, this.clientNom});

  @override
  ConsumerState<_AddCollecteDialog> createState() => _AddCollecteDialogState();
}

class _AddCollecteDialogState extends ConsumerState<_AddCollecteDialog> {
  static const _maxJours = 31;

  int _nbJours = 1;
  DateTime _date = DateTime.now();
  bool _confirme = false;
  bool _isSaving = false;
  Transaction? _transactionEnregistree;

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
      final transaction = await ref.read(transactionRepositoryProvider).createCollecte(
            compteId: widget.compte.id,
            date: _date,
            nbJours: _nbJours,
          );
      ref.invalidate(compteSoldeProvider(widget.compte.id));
      if (mounted) {
        // Dialogue gardé ouvert pour proposer l'impression du reçu.
        setState(() {
          _isSaving = false;
          _transactionEnregistree = transaction;
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
          const SnackBar(content: Text("Impossible d'enregistrer la collecte")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final transaction = _transactionEnregistree;
    final soldeAsync = ref.watch(compteSoldeProvider(widget.compte.id));
    final joursManques = soldeAsync.valueOrNull?.joursManques ?? 0;

    if (transaction != null) {
      return AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Theme.of(context).colorScheme.secondary),
            const SizedBox(width: 8),
            const Expanded(child: Text('Collecte enregistrée')),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () => imprimerRecu(
              context,
              ref,
              transaction: transaction,
              compteNumero: widget.compte.numeroCompte,
              clientNom: widget.clientNom ?? '',
            ),
            icon: const Icon(Icons.print_outlined, size: 18),
            label: const Text('Imprimer le reçu'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Terminer'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: const Text('Enregistrer une collecte'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.clientNom != null) ...[
              Text('Client : ${widget.clientNom}'),
              const SizedBox(height: 4),
            ],
            Text('N° de compte : ${widget.compte.numeroCompte}'),
            if (joursManques > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$joursManques jour(s) manqué(s) — choisissez le nombre de jours à '
                  'payer pour les couvrir.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text('Nombre de jours à payer', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: _nbJours > 1 ? () => setState(() => _nbJours--) : null,
                  icon: const Icon(Icons.remove),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    '$_nbJours',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: _nbJours < _maxJours ? () => setState(() => _nbJours++) : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Montant (calculé)', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    '${_amountFormat.format(_montant)} HTG',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text(_dateFormat.format(_date)),
              trailing: const Icon(Icons.calendar_today, size: 20),
              onTap: _pickDate,
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _confirme,
              onChanged: (v) => setState(() => _confirme = v ?? false),
              title: const Text(
                'Je confirme avoir reçu ce montant en espèces du client.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: (_confirme && !_isSaving) ? _save : null,
          child: _isSaving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enregistrer'),
        ),
      ],
    );
  }
}
