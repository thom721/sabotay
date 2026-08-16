import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/async_state_views.dart';
import '../../../core/widgets/dashboard_shell.dart';
import '../data/entreprise_repository.dart';
import '../domain/entreprise_profile.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/user.dart';
import '../../auth/presentation/auth_controller.dart';

/// Fiche entreprise : informations générales + format de reçu (édition
/// réservée à l'Admin côté backend) et changement du mot de passe personnel
/// (ouvert à tout utilisateur connecté) — PRD §8.5.
class EntrepriseProfileScreen extends ConsumerWidget {
  const EntrepriseProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(entrepriseProfileProvider);
    final currentUser = ref.watch(authControllerProvider).value;
    final isAdmin = currentUser?.role == RoleUtilisateur.admin;

    return DashboardContent(
      title: 'Entreprise',
      backgroundColor: const Color(0xFFF0F2F5),
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
          if (isAdmin) ...[
            const SizedBox(height: 24),
            Text('Installation bureau', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            const _CodeInstallationCard(),
          ],
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

/// Code d'installation bureau (Epic 2/5) — saisi dans l'assistant
/// d'installation du poste local pour le lier au cloud sans email/mot de
/// passe. Régénérer invalide l'ancien code (voir POST côté backend).
class _CodeInstallationCard extends ConsumerWidget {
  const _CodeInstallationCard();

  Future<void> _regenerer(BuildContext context, WidgetRef ref) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Régénérer le code ?'),
        content: const Text(
          'L\'ancien code d\'installation ne fonctionnera plus. À utiliser si '
          'vous devez refaire l\'installation sur un nouveau poste.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Régénérer'),
          ),
        ],
      ),
    );
    if (confirme != true) return;

    try {
      await ref.read(entrepriseRepositoryProvider).regenererCodeInstallation();
      ref.invalidate(codeInstallationProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nouveau code généré')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de régénérer le code')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final codeAsync = ref.watch(codeInstallationProvider);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: codeAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, _) => ErrorState(
            message: 'Impossible de charger le code d\'installation',
            onRetry: () => ref.invalidate(codeInstallationProvider),
          ),
          data: (code) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'À saisir dans l\'assistant d\'installation du poste bureau '
                '(pas besoin d\'email ni de mot de passe).',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        code.code ?? '—',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontFeatures: const [FontFeature.tabularFigures()],
                              letterSpacing: 2,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Copier',
                    icon: const Icon(Icons.copy_outlined),
                    onPressed: code.code == null
                        ? null
                        : () {
                            Clipboard.setData(ClipboardData(text: code.code!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Code copié')),
                            );
                          },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (code.utilise)
                Text(
                  'Ce code a déjà été utilisé pour lier un poste.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _regenerer(context, ref),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Régénérer'),
                ),
              ),
            ],
          ),
        ),
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

// Taille max côté client (≈1 Mo décodé) — même plafond que le backend
// (voir _TAILLE_MAX_LOGO_DATA, endpoints/entreprises.py) : évite un
// aller-retour réseau juste pour se faire rejeter par le serveur.
const _tailleMaxLogoOctets = 1000000;

class _ProfileInfoCardState extends ConsumerState<_ProfileInfoCard> {
  final _formKey = GlobalKey<FormState>();
  late final _nomController = TextEditingController(text: widget.profile.nom);
  late final _adresseController = TextEditingController(text: widget.profile.adresse ?? '');
  late final _telephoneController =
      TextEditingController(text: widget.profile.telephoneContact ?? '');
  late final _fraisRetraitController =
      TextEditingController(text: widget.profile.fraisRetrait.toString());
  late String? _logoData = widget.profile.logoData;
  bool _isSaving = false;

  @override
  void dispose() {
    _nomController.dispose();
    _adresseController.dispose();
    _telephoneController.dispose();
    _fraisRetraitController.dispose();
    super.dispose();
  }

  Future<void> _choisirLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final fichier = result?.files.firstOrNull;
    if (fichier == null || fichier.bytes == null) return;

    if (fichier.bytes!.length > _tailleMaxLogoOctets) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image trop volumineuse (max ~1 Mo)')),
        );
      }
      return;
    }

    final extension = (fichier.extension ?? '').toLowerCase();
    final mime = switch (extension) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/png',
    };
    setState(() {
      _logoData = 'data:$mime;base64,${base64Encode(fichier.bytes!)}';
    });
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
            fraisRetrait: num.tryParse(_fraisRetraitController.text.trim()) ?? 0,
            logoData: _logoData,
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
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      border: Border.all(color: colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _logoData == null
                        ? Icon(Icons.storefront_outlined, color: colorScheme.onSurfaceVariant)
                        : Image.memory(
                            base64Decode(_logoData!.split(',').last),
                            fit: BoxFit.contain,
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Logo', style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 4),
                        OutlinedButton.icon(
                          onPressed: _choisirLogo,
                          icon: const Icon(Icons.upload_outlined, size: 16),
                          label: Text(_logoData == null ? 'Ajouter un logo' : 'Changer le logo'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
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
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Téléphone de contact (optionnel)'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fraisRetraitController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Frais de retrait',
                  helperText: 'Déduit du montant demandé par le client au moment du retrait — '
                      'le client reçoit le montant demandé moins ce frais. 0 = aucun frais.',
                  helperMaxLines: 2,
                ),
                validator: (value) {
                  final v = num.tryParse((value ?? '').trim());
                  if (v == null || v < 0) return 'Montant invalide';
                  return null;
                },
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
