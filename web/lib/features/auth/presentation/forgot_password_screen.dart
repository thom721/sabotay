import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'password_reset_controller.dart';

/// Réinitialisation de mot de passe (Web uniquement — PRD §5.3), en deux
/// étapes : demande d'un code par SMS ou email, puis confirmation avec un
/// nouveau mot de passe.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _requestFormKey = GlobalKey<FormState>();
  final _confirmFormKey = GlobalKey<FormState>();

  final _identifiantController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _canal = 'sms';
  bool _obscurePassword = true;

  @override
  void dispose() {
    _identifiantController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (!_requestFormKey.currentState!.validate()) return;
    await ref.read(passwordResetControllerProvider.notifier).requestCode(
          identifiant: _identifiantController.text.trim(),
          canal: _canal,
        );
  }

  Future<void> _submitConfirm() async {
    if (!_confirmFormKey.currentState!.validate()) return;
    await ref.read(passwordResetControllerProvider.notifier).confirmReset(
          code: _codeController.text.trim(),
          nouveauMotDePasse: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final resetState = ref.watch(passwordResetControllerProvider);
    final isLoading = resetState.isLoading;
    final step = resetState.valueOrNull?.step ?? PasswordResetStep.request;

    ref.listen(passwordResetControllerProvider, (previous, next) {
      if (next.hasError && !next.isLoading) {
        final wasConfirming =
            previous?.valueOrNull?.step == PasswordResetStep.confirm;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              wasConfirming
                  ? 'Code invalide ou expiré.'
                  : 'Une erreur est survenue. Réessayez.',
            ),
          ),
        );
        return;
      }
      if (next.valueOrNull?.step == PasswordResetStep.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mot de passe mis à jour.')),
        );
        context.go('/login');
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Mot de passe oublié')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: step == PasswordResetStep.request
                  ? _buildRequestStep(isLoading)
                  : _buildConfirmStep(isLoading),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestStep(bool isLoading) {
    return Form(
      key: _requestFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Recevoir un code',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Entrez votre téléphone ou email pour recevoir un code de réinitialisation.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _identifiantController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Téléphone ou email'),
            validator: (value) =>
                (value == null || value.trim().isEmpty) ? 'Champ requis' : null,
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'sms', label: Text('SMS')),
              ButtonSegment(value: 'email', label: Text('Email')),
            ],
            selected: {_canal},
            onSelectionChanged: isLoading
                ? null
                : (value) => setState(() => _canal = value.first),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: isLoading ? null : _submitRequest,
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Envoyer le code'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.go('/login'),
            child: const Text('Retour à la connexion'),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmStep(bool isLoading) {
    return Form(
      key: _confirmFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Nouveau mot de passe',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Entrez le code reçu ainsi que votre nouveau mot de passe.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Code à 6 chiffres'),
            validator: (value) =>
                (value == null || value.trim().length != 6) ? 'Code à 6 chiffres' : null,
          ),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Nouveau mot de passe',
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (value) =>
                (value == null || value.length < 6) ? 'Au moins 6 caractères' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(labelText: 'Confirmer le mot de passe'),
            validator: (value) => value != _passwordController.text
                ? 'Les mots de passe ne correspondent pas'
                : null,
            onFieldSubmitted: (_) => _submitConfirm(),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: isLoading ? null : _submitConfirm,
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Réinitialiser le mot de passe'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: isLoading
                ? null
                : () => ref.read(passwordResetControllerProvider.notifier).backToRequest(),
            child: const Text('Recevoir un nouveau code'),
          ),
        ],
      ),
    );
  }
}
