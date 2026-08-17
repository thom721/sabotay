import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../comptes/domain/compte_sabotay.dart';
import '../../comptes/presentation/compte_providers.dart';
import '../../entreprise/data/entreprise_repository.dart';
import '../data/transaction_repository.dart';
import '../domain/transaction.dart';
import 'recu_pdf.dart';

final _dateFormat = DateFormat('dd/MM/yyyy');
final _amountFormat = NumberFormat.decimalPattern('fr');

/// Équivalent bureau/web de `retrait_sheet.dart` (mobile) — retrait partiel
/// plafonné au solde disponible, les frais viennent de la configuration
/// entreprise (jamais modifiables ici).
Future<void> showRetraitSheet(
  BuildContext context,
  CompteSabotay compte, {
  String? clientNom,
}) {
  return showDialog(
    context: context,
    builder: (context) => _RetraitDialog(compte: compte, clientNom: clientNom),
  );
}

class _RetraitDialog extends ConsumerStatefulWidget {
  final CompteSabotay compte;
  final String? clientNom;

  const _RetraitDialog({required this.compte, this.clientNom});

  @override
  ConsumerState<_RetraitDialog> createState() => _RetraitDialogState();
}

class _RetraitDialogState extends ConsumerState<_RetraitDialog> {
  final _formKey = GlobalKey<FormState>();
  final _montantController = TextEditingController();
  DateTime _date = DateTime.now();
  bool _confirme = false;
  bool _isSaving = false;
  Transaction? _transactionEnregistree;

  @override
  void dispose() {
    _montantController.dispose();
    super.dispose();
  }

  num get _montantDemande => num.tryParse(_montantController.text.trim()) ?? 0;

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
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final transaction = await ref.read(transactionRepositoryProvider).createRetrait(
            compteId: widget.compte.id,
            date: _date,
            montant: _montantDemande,
          );
      ref.invalidate(compteSoldeProvider(widget.compte.id));
      if (mounted) {
        setState(() {
          _isSaving = false;
          _transactionEnregistree = transaction;
        });
      }
    } on MontantRetraitInvalideException {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Montant supérieur au solde disponible')),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossible d'enregistrer le retrait")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final transaction = _transactionEnregistree;
    final soldeAsync = ref.watch(compteSoldeProvider(widget.compte.id));
    final entrepriseAsync = ref.watch(entrepriseProfileProvider);
    final frais = entrepriseAsync.valueOrNull?.fraisRetrait ?? 0;
    final soldeDisponible = soldeAsync.valueOrNull?.soldeDisponible ?? 0;

    if (transaction != null) {
      return AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Theme.of(context).colorScheme.secondary),
            const SizedBox(width: 8),
            const Expanded(child: Text('Retrait enregistré')),
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

    final montantNet = _montantDemande - frais;

    return AlertDialog(
      title: const Text('Enregistrer un retrait'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.clientNom != null) ...[
                Text('Client : ${widget.clientNom}'),
                const SizedBox(height: 4),
              ],
              Text('N° de compte : ${widget.compte.numeroCompte}'),
              const SizedBox(height: 4),
              Text(
                'Solde disponible : ${_amountFormat.format(soldeDisponible)} HTG',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _montantController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Montant demandé (HTG)'),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  final parsed = num.tryParse((value ?? '').trim());
                  if (parsed == null || parsed <= 0) return 'Montant invalide';
                  if (parsed > soldeDisponible) return 'Supérieur au solde disponible';
                  return null;
                },
              ),
              if (frais > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Frais : ${_amountFormat.format(frais)} HTG · Montant net remis : '
                  '${_amountFormat.format(montantNet < 0 ? 0 : montantNet)} HTG',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
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
                  'Je confirme avoir remis ce montant en espèces au client.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
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
