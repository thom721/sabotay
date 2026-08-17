import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../comptes/domain/compte_sabotay.dart';
import '../../comptes/presentation/compte_providers.dart';
import '../../entreprise/presentation/entreprise_providers.dart';
import '../data/transaction_repository.dart';
import '../domain/retrait_result.dart';
import '../domain/transaction.dart';
import 'recu_pdf.dart';

final _confirmDateFormat = DateFormat('dd/MM/yyyy');
final _confirmAmountFormat = NumberFormat.decimalPattern('fr');

Future<void> showRetraitSheet(
  BuildContext context,
  CompteSabotay compte, {
  String? clientNom,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => _RetraitSheet(compte: compte, clientNom: clientNom),
  );
}

/// Retrait partiel, possible à tout moment — plafonné au solde disponible.
/// Les frais viennent de la configuration entreprise (jamais modifiables
/// dans l'app) ; seul le montant demandé est choisi par l'agent/le client,
/// avec les mêmes trois étapes de confirmation que la collecte.
class _RetraitSheet extends ConsumerStatefulWidget {
  final CompteSabotay compte;
  final String? clientNom;

  const _RetraitSheet({required this.compte, this.clientNom});

  @override
  ConsumerState<_RetraitSheet> createState() => _RetraitSheetState();
}

class _RetraitSheetState extends ConsumerState<_RetraitSheet> {
  final _formKey = GlobalKey<FormState>();
  final _montantController = TextEditingController();
  int _step = 0;
  DateTime _date = DateTime.now();
  bool _isSaving = false;
  Transaction? _transactionEnregistree;
  RetraitQueued? _retraitEnAttente;

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
    setState(() => _isSaving = true);
    try {
      final result = await ref.read(transactionRepositoryProvider).createRetrait(
            compteId: widget.compte.id,
            date: _date,
            montant: _montantDemande,
          );
      if (result is RetraitSuccess) {
        ref.invalidate(compteSoldeProvider(widget.compte.id));
      }
      if (mounted) {
        // Feuille gardée ouverte pour proposer l'impression du reçu (ou
        // afficher l'état "en attente") — même raisonnement que
        // add_collecte_sheet.dart.
        setState(() {
          _isSaving = false;
          switch (result) {
            case RetraitSuccess(:final transaction):
              _transactionEnregistree = transaction;
            case RetraitQueued():
              _retraitEnAttente = result;
          }
        });
      }
    } on MontantRetraitInvalideException {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _step = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Montant supérieur au solde disponible'),
        ));
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
    final retraitEnAttente = _retraitEnAttente;
    final soldeAsync = ref.watch(compteSoldeProvider(widget.compte.id));
    final entrepriseAsync = ref.watch(entrepriseProfilProvider);
    final frais = entrepriseAsync.valueOrNull?.fraisRetrait ?? 0;
    final montantNet = (_montantDemande - frais).clamp(0, double.infinity).toDouble();

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: transaction != null
          ? _RetraitEnregistreView(
              transaction: transaction,
              compte: widget.compte,
              clientNom: widget.clientNom ?? '',
            )
          : retraitEnAttente != null
              ? _RetraitEnAttenteView(resultat: retraitEnAttente)
              : switch (_step) {
              0 => _FormulaireStep(
                  formKey: _formKey,
                  montantController: _montantController,
                  soldeAsync: soldeAsync,
                  frais: frais,
                  date: _date,
                  onPickDate: _pickDate,
                  onSuivant: () {
                    if (_formKey.currentState!.validate()) setState(() => _step = 1);
                  },
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
                    _ConfirmRow('Montant demandé', '${_confirmAmountFormat.format(_montantDemande)} HTG'),
                    _ConfirmRow('Frais', '${_confirmAmountFormat.format(frais)} HTG'),
                    _ConfirmRow('Montant net à remettre', '${_confirmAmountFormat.format(montantNet)} HTG'),
                    _ConfirmRow('Date', _confirmDateFormat.format(_date)),
                  ],
                  onRetour: () => setState(() => _step = 1),
                  onSuivant: () => setState(() => _step = 3),
                ),
              _ => _ConfirmationFinaleStep(
                  clientNom: widget.clientNom,
                  compte: widget.compte,
                  montantDemande: _montantDemande,
                  montantNet: montantNet,
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
  final GlobalKey<FormState> formKey;
  final TextEditingController montantController;
  final AsyncValue<CompteSolde> soldeAsync;
  final num frais;
  final DateTime date;
  final VoidCallback onPickDate;
  final VoidCallback onSuivant;

  const _FormulaireStep({
    required this.formKey,
    required this.montantController,
    required this.soldeAsync,
    required this.frais,
    required this.date,
    required this.onPickDate,
    required this.onSuivant,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final soldeDisponible = soldeAsync.valueOrNull?.soldeDisponible ?? 0;

    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Effectuer un retrait', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Solde disponible : ${_confirmAmountFormat.format(soldeDisponible)} HTG',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: montantController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Montant à retirer (HTG)'),
            validator: (value) {
              final parsed = num.tryParse(value?.trim() ?? '');
              if (parsed == null || parsed <= 0) return 'Montant invalide';
              if (parsed > soldeDisponible) return 'Supérieur au solde disponible';
              return null;
            },
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: montantController,
            builder: (context, value, _) {
              final montantDemande = num.tryParse(value.text.trim()) ?? 0;
              final montantNet = (montantDemande - frais).clamp(0, double.infinity);
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LigneMontant('Frais (configurés par l\'entreprise)', frais),
                    const SizedBox(height: 4),
                    _LigneMontant('Montant net à remettre', montantNet, gras: true),
                  ],
                ),
              );
            },
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
      ),
    );
  }
}

class _LigneMontant extends StatelessWidget {
  final String label;
  final num montant;
  final bool gras;

  const _LigneMontant(this.label, this.montant, {this.gras = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          '${_confirmAmountFormat.format(montant)} HTG',
          style: TextStyle(fontWeight: gras ? FontWeight.bold : FontWeight.normal),
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
  final num montantDemande;
  final num montantNet;
  final DateTime date;
  final bool isSaving;
  final VoidCallback onRetour;
  final VoidCallback onConfirmer;

  const _ConfirmationFinaleStep({
    required this.clientNom,
    required this.compte,
    required this.montantDemande,
    required this.montantNet,
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
        _ConfirmRow('Montant net remis', '${_confirmAmountFormat.format(montantNet)} HTG'),
        _ConfirmRow('Date', _confirmDateFormat.format(date)),
        const SizedBox(height: 16),
        Text(
          'Je confirme avoir remis ce montant en espèces au client.',
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

class _RetraitEnregistreView extends ConsumerWidget {
  final Transaction transaction;
  final CompteSabotay compte;
  final String clientNom;

  const _RetraitEnregistreView({
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
              child: Text('Retrait enregistré', style: Theme.of(context).textTheme.titleLarge),
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

class _RetraitEnAttenteView extends StatelessWidget {
  final RetraitQueued resultat;

  const _RetraitEnAttenteView({required this.resultat});

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
                'Retrait enregistré localement',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Pas de connexion — sera synchronisé automatiquement dès que le '
          'réseau revient. Le montant sera revérifié par le serveur à ce '
          'moment-là.',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _ConfirmRow(
            'Montant demandé',
            '${_confirmAmountFormat.format(resultat.montant)} HTG',
          ),
        ),
        const SizedBox(height: 16),
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
