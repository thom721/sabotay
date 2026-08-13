import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/compte_repository.dart';
import 'compte_providers.dart';

Future<void> showCreateCompteSheet(BuildContext context, String clientId) {
  return showDialog(
    context: context,
    builder: (context) => _CreateCompteSheet(clientId: clientId),
  );
}

class _CreateCompteSheet extends ConsumerStatefulWidget {
  final String clientId;
  const _CreateCompteSheet({required this.clientId});

  @override
  ConsumerState<_CreateCompteSheet> createState() => _CreateCompteSheetState();
}

class _CreateCompteSheetState extends ConsumerState<_CreateCompteSheet> {
  final _formKey = GlobalKey<FormState>();
  final _montantController = TextEditingController();
  final _dureeController = TextEditingController();
  DateTime _dateDebut = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _montantController.dispose();
    _dureeController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateDebut,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dateDebut = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(compteRepositoryProvider).create(
            clientId: widget.clientId,
            montantJournalier: num.parse(_montantController.text.trim()),
            dateDebut: _dateDebut,
            dureeJours: int.parse(_dureeController.text.trim()),
          );
      ref.invalidate(clientComptesProvider(widget.clientId));
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de créer le compte')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouveau compte Sabotay'),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            TextFormField(
              controller: _montantController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Montant journalier (HTG)'),
              validator: (value) {
                final parsed = num.tryParse((value ?? '').trim());
                if (parsed == null || parsed <= 0) return 'Montant invalide';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _dureeController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(labelText: 'Durée (jours)'),
              validator: (value) {
                final parsed = int.tryParse((value ?? '').trim());
                if (parsed == null || parsed <= 0) return 'Durée invalide';
                return null;
              },
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text('Début : ${DateFormat('dd/MM/yyyy').format(_dateDebut)}'),
            ),
            const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Créer le compte'),
        ),
      ],
    );
  }
}
