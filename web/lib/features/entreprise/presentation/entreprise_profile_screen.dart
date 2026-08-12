import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/async_state_views.dart';
import '../../../core/widgets/dashboard_shell.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../data/entreprise_repository.dart';
import '../domain/entreprise_profile.dart';
import '../../auth/data/auth_repository.dart';

/// Fiche entreprise : informations générales + format de reçu (édition
/// réservée à l'Admin côté backend) et changement du mot de passe personnel
/// (ouvert à tout utilisateur connecté) — PRD §8.5.
class EntrepriseProfileScreen extends ConsumerWidget {
  const EntrepriseProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(entrepriseProfileProvider);

    return DashboardShell(
      title: 'Entreprise',
      currentRoute: '/admin/entreprise',
      navItems: adminNavItems,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Informations de l\'entreprise', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          profileAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => ErrorState(
              message: 'Impossible de charger les informations de l\'entreprise',
              onRetry: () => ref.invalidate(entrepriseProfileProvider),
            ),
            data: (profile) => _ProfileInfoCard(profile: profile),
          ),
          const SizedBox(height: 24),
          Text('Paramètres du reçu', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          profileAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => ErrorState(
              message: 'Impossible de charger les paramètres du reçu',
              onRetry: () => ref.invalidate(entrepriseProfileProvider),
            ),
            data: (profile) => _ReceiptSettingsCard(profile: profile),
          ),
          const SizedBox(height: 24),
          Text('Changer mon mot de passe', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          const _ChangePasswordCard(),
        ],
      ),
    );
  }
}

const _formatRecuOptions = [
  DropdownMenuItem(value: '58mm', child: Text('Reçu 58mm')),
  DropdownMenuItem(value: '80mm', child: Text('Reçu 80mm')),
];

class _ProfileInfoCard extends ConsumerStatefulWidget {
  final EntrepriseProfile profile;
  const _ProfileInfoCard({required this.profile});

  @override
  ConsumerState<_ProfileInfoCard> createState() => _ProfileInfoCardState();
}

class _ProfileInfoCardState extends ConsumerState<_ProfileInfoCard> {
  final _formKey = GlobalKey<FormState>();
  late final _nomController = TextEditingController(text: widget.profile.nom);
  late final _adresseController = TextEditingController(text: widget.profile.adresse ?? '');
  late final _telephoneController =
      TextEditingController(text: widget.profile.telephoneContact ?? '');
  bool _isSaving = false;

  @override
  void dispose() {
    _nomController.dispose();
    _adresseController.dispose();
    _telephoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(entrepriseRepositoryProvider).updateProfile(
            nom: _nomController.text.trim(),
            adresse: _adresseController.text.trim().isEmpty
                ? null
                : _adresseController.text.trim(),
            telephoneContact: _telephoneController.text.trim().isEmpty
                ? null
                : _telephoneController.text.trim(),
          );
      ref.invalidate(entrepriseProfileProvider);
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informations mises à jour')),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'enregistrer les modifications')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nomController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Nom de l\'entreprise'),
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
              TextFormField(
                controller: _telephoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(labelText: 'Téléphone de contact (optionnel)'),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Enregistrer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiptSettingsCard extends ConsumerStatefulWidget {
  final EntrepriseProfile profile;
  const _ReceiptSettingsCard({required this.profile});

  @override
  ConsumerState<_ReceiptSettingsCard> createState() => _ReceiptSettingsCardState();
}

class _ReceiptSettingsCardState extends ConsumerState<_ReceiptSettingsCard> {
  final _formKey = GlobalKey<FormState>();
  late final _texteBasRecuController =
      TextEditingController(text: widget.profile.texteBasRecu ?? '');
  late String _formatRecu = widget.profile.formatRecu;
  bool _isSaving = false;

  @override
  void dispose() {
    _texteBasRecuController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(entrepriseRepositoryProvider).updateProfile(
            formatRecu: _formatRecu,
            texteBasRecu: _texteBasRecuController.text.trim().isEmpty
                ? null
                : _texteBasRecuController.text.trim(),
          );
      ref.invalidate(entrepriseProfileProvider);
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paramètres du reçu mis à jour')),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'enregistrer les modifications')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                value: _formatRecu,
                decoration: const InputDecoration(labelText: 'Format de reçu'),
                items: _formatRecuOptions,
                onChanged: (value) => setState(() => _formatRecu = value ?? _formatRecu),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _texteBasRecuController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Texte de bas de reçu (optionnel)',
                  hintText: 'Merci de votre confiance',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Enregistrer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChangePasswordCard extends ConsumerStatefulWidget {
  const _ChangePasswordCard();

  @override
  ConsumerState<_ChangePasswordCard> createState() => _ChangePasswordCardState();
}

class _ChangePasswordCardState extends ConsumerState<_ChangePasswordCard> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(authRepositoryProvider).changePassword(
            motDePasseActuel: _currentPasswordController.text,
            nouveauMotDePasse: _newPasswordController.text,
          );
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mot de passe mis à jour')),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mot de passe actuel incorrect')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _currentPasswordController,
                obscureText: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Mot de passe actuel'),
                validator: (value) =>
                    (value == null || value.isEmpty) ? 'Champ requis' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newPasswordController,
                obscureText: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Nouveau mot de passe'),
                validator: (value) =>
                    (value == null || value.length < 6) ? 'Au moins 6 caractères' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(labelText: 'Confirmer le mot de passe'),
                validator: (value) => value != _newPasswordController.text
                    ? 'Les mots de passe ne correspondent pas'
                    : null,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Mettre à jour'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
