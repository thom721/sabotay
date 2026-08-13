import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'client_list_controller.dart';

final _dateFormat = DateFormat('dd/MM/yyyy');

Future<void> showAddClientSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _AddClientSheet(),
  );
}

class _AddClientSheet extends ConsumerStatefulWidget {
  const _AddClientSheet();

  @override
  ConsumerState<_AddClientSheet> createState() => _AddClientSheetState();
}

class _AddClientSheetState extends ConsumerState<_AddClientSheet> {
  final _formKey = GlobalKey<FormState>();
  final _prenomController = TextEditingController();
  final _nomController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _adresseController = TextEditingController();
  final _nifCinController = TextEditingController();
  final _heritierNomController = TextEditingController();
  final _heritierPrenomController = TextEditingController();
  final _heritierAdresseController = TextEditingController();
  final _heritierTelephoneController = TextEditingController();
  DateTime? _dateNaissance;
  bool _isSaving = false;

  @override
  void dispose() {
    _prenomController.dispose();
    _nomController.dispose();
    _telephoneController.dispose();
    _emailController.dispose();
    _adresseController.dispose();
    _nifCinController.dispose();
    _heritierNomController.dispose();
    _heritierPrenomController.dispose();
    _heritierAdresseController.dispose();
    _heritierTelephoneController.dispose();
    super.dispose();
  }

  Future<void> _pickDateNaissance() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateNaissance ?? DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dateNaissance = picked);
  }

  String? _emptyToNull(TextEditingController controller) =>
      controller.text.trim().isEmpty ? null : controller.text.trim();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(clientListControllerProvider.notifier).addClient(
            nom: _nomController.text.trim(),
            prenom: _prenomController.text.trim(),
            telephone: _telephoneController.text.trim(),
            adresse: _emptyToNull(_adresseController),
            dateNaissance: _dateNaissance,
            nifCin: _emptyToNull(_nifCinController),
            email: _emptyToNull(_emailController),
            heritierNom: _emptyToNull(_heritierNomController),
            heritierPrenom: _emptyToNull(_heritierPrenomController),
            heritierAdresse: _emptyToNull(_heritierAdresseController),
            heritierTelephone: _emptyToNull(_heritierTelephoneController),
          );
      if (mounted) Navigator.of(context).pop();
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      final detail = e.response?.statusCode == 409 ? e.response?.data['detail'] : null;
      if (detail is Map) {
        await _showDuplicateDialog(
          nomExistant: detail['client_existant_nom'] as String,
          clientExistantId: detail['client_existant_id'] as String,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de créer le client')),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de créer le client')),
        );
      }
    }
  }

  /// Un client avec les mêmes nom/prénom/date de naissance (ou même nif/cin)
  /// existe déjà dans cette entreprise (backend `find_duplicate`, 409) — on
  /// guide vers la création d'un compte Sabotay pour ce client plutôt que
  /// de laisser créer un doublon.
  Future<void> _showDuplicateDialog({
    required String nomExistant,
    required String clientExistantId,
  }) async {
    if (!mounted) return;
    final creerCompte = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Client déjà existant'),
        content: Text(
          'Un client avec des informations similaires existe déjà : $nomExistant.\n\n'
          'Voulez-vous plutôt lui créer un nouveau compte Sabotay ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Créer un compte Sabotay'),
          ),
        ],
      ),
    );
    if (creerCompte == true && mounted) {
      Navigator.of(context).pop();
      GoRouter.of(context).push('/admin/clients/$clientExistantId');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Nouveau client', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Text('Informations personnelles', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final prenomField = TextFormField(
                    controller: _prenomController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Prénom'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty) ? 'Champ requis' : null,
                  );
                  final nomField = TextFormField(
                    controller: _nomController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Nom'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty) ? 'Champ requis' : null,
                  );
                  if (constraints.maxWidth < 420) {
                    return Column(
                      children: [
                        prenomField,
                        const SizedBox(height: 16),
                        nomField,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: prenomField),
                      const SizedBox(width: 16),
                      Expanded(child: nomField),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _telephoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Téléphone'),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Champ requis' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Email (optionnel)',
                  helperText:
                      'Si renseigné, le client recevra un accès à son espace personnel par email',
                  helperMaxLines: 2,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _adresseController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Adresse (optionnel)'),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDateNaissance,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Date de naissance (optionnel)'),
                  child: Text(
                    _dateNaissance == null ? 'Sélectionner une date' : _dateFormat.format(_dateNaissance!),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nifCinController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(labelText: 'NIF/CIN (optionnel)'),
              ),
              const SizedBox(height: 24),
              Text('Héritier (bénéficiaire)', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Personne à contacter en cas de décès du client',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _heritierPrenomController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Prénom (optionnel)'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _heritierNomController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Nom (optionnel)'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _heritierAdresseController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Adresse (optionnel)'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _heritierTelephoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(labelText: 'Téléphone (optionnel)'),
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Créer le client'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
