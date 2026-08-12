import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/domain/user.dart';
import 'employee_list_controller.dart';

final _dateFormat = DateFormat('dd/MM/yyyy');

Future<void> showInviteEmployeeSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _InviteEmployeeSheet(),
  );
}

String _roleLabel(RoleUtilisateur role) => switch (role) {
      RoleUtilisateur.admin => 'Admin',
      RoleUtilisateur.manager => 'Manager',
      RoleUtilisateur.agent => 'Agent',
    };

class _InviteEmployeeSheet extends ConsumerStatefulWidget {
  const _InviteEmployeeSheet();

  @override
  ConsumerState<_InviteEmployeeSheet> createState() => _InviteEmployeeSheetState();
}

class _InviteEmployeeSheetState extends ConsumerState<_InviteEmployeeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _prenomController = TextEditingController();
  final _nomController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _adresseController = TextEditingController();
  final _nifCinController = TextEditingController();
  DateTime? _dateNaissance;
  RoleUtilisateur _role = RoleUtilisateur.agent;
  bool _isSaving = false;

  @override
  void dispose() {
    _prenomController.dispose();
    _nomController.dispose();
    _telephoneController.dispose();
    _emailController.dispose();
    _adresseController.dispose();
    _nifCinController.dispose();
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
      await ref.read(employeeListControllerProvider.notifier).invite(
            nom: _nomController.text.trim(),
            prenom: _prenomController.text.trim(),
            telephone: _telephoneController.text.trim(),
            email: _emailController.text.trim(),
            dateNaissance: _dateNaissance,
            nifCin: _emptyToNull(_nifCinController),
            adresse: _emptyToNull(_adresseController),
            role: _role,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de créer cet employé')),
        );
      }
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
              Text('Inviter un employé', style: Theme.of(context).textTheme.titleLarge),
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
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Champ requis' : null,
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
                    _dateNaissance == null
                        ? 'Sélectionner une date'
                        : _dateFormat.format(_dateNaissance!),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nifCinController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'NIF/CIN (optionnel)'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<RoleUtilisateur>(
                value: _role,
                decoration: const InputDecoration(labelText: 'Rôle'),
                items: RoleUtilisateur.values
                    .map(
                      (role) => DropdownMenuItem(value: role, child: Text(_roleLabel(role))),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _role = value ?? RoleUtilisateur.agent),
              ),
              const SizedBox(height: 8),
              Text(
                'Un mot de passe temporaire sera envoyé par email à l\'employé.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                    : const Text('Créer le compte'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
