import 'package:flutter/material.dart';

/// Formulaire de changement de mot de passe, partagé entre le flux forcé
/// (`force_password_change_screen.dart`, compte créé/réinitialisé par un
/// Admin) et le changement volontaire (bouton profil sur l'accueil, ou côté
/// portail Client) — seul le callback `onSubmit` diffère selon l'identité
/// (Utilisateur ou Client).
class ChangePasswordForm extends StatefulWidget {
  final Future<void> Function(String motDePasseActuel, String nouveauMotDePasse) onSubmit;
  final VoidCallback? onSuccess;
  final String submitLabel;
  final String erreurMessage;

  const ChangePasswordForm({
    super.key,
    required this.onSubmit,
    this.onSuccess,
    this.submitLabel = 'Mettre à jour',
    this.erreurMessage = 'Mot de passe actuel incorrect',
  });

  @override
  State<ChangePasswordForm> createState() => _ChangePasswordFormState();
}

class _ChangePasswordFormState extends State<ChangePasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isSaving = false;
  bool _obscure = true;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await widget.onSubmit(_currentController.text, _newController.text);
      widget.onSuccess?.call();
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.erreurMessage)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _currentController,
            obscureText: _obscure,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Mot de passe actuel'),
            validator: (v) => (v == null || v.isEmpty) ? 'Champ requis' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _newController,
            obscureText: _obscure,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Nouveau mot de passe',
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) => (v == null || v.length < 6) ? 'Au moins 6 caractères' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmController,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(labelText: 'Confirmer le mot de passe'),
            validator: (v) =>
                v != _newController.text ? 'Les mots de passe ne correspondent pas' : null,
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
                : Text(widget.submitLabel),
          ),
        ],
      ),
    );
  }
}
