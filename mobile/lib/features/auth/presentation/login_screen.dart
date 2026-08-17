import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../client_portal/presentation/client_auth_controller.dart';
import 'auth_controller.dart';

/// Connexion mobile — bascule Employé (Admin/Manager/Agent, connexion par
/// téléphone ou email) / Client (portail libre-service, connexion par
/// email uniquement — PRD §8.8). Le routeur redirige ensuite vers l'écran
/// adapté. Pas d'inscription ni de "mot de passe oublié" ici : réservées au
/// web (§5.3).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifiantController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _modeClient = false;

  @override
  void dispose() {
    _identifiantController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_modeClient) {
      await ref.read(clientAuthControllerProvider.notifier).login(
            email: _identifiantController.text.trim(),
            password: _passwordController.text,
          );
      if (ref.read(clientAuthControllerProvider).valueOrNull != null) {
        ref.read(authControllerProvider.notifier).clearSilently();
      }
    } else {
      await ref.read(authControllerProvider.notifier).login(
            identifiant: _identifiantController.text.trim(),
            password: _passwordController.text,
          );
      if (ref.read(authControllerProvider).valueOrNull != null) {
        ref.read(clientAuthControllerProvider.notifier).clearSilently();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final clientAuthState = ref.watch(clientAuthControllerProvider);
    final isLoading = _modeClient ? clientAuthState.isLoading : authState.isLoading;

    ref.listen(authControllerProvider, (previous, next) {
      if (!_modeClient && next.hasError && !next.isLoading) {
        final erreur = next.error;
        final message = erreur is SyncEnAttenteException
            ? erreur.message
            : 'Téléphone/email ou mot de passe incorrect';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    });
    ref.listen(clientAuthControllerProvider, (previous, next) {
      if (_modeClient && next.hasError && !next.isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email ou mot de passe incorrect')),
        );
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'SabotayPro',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Connexion',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 24),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('Employé')),
                        ButtonSegment(value: true, label: Text('Client')),
                      ],
                      selected: {_modeClient},
                      onSelectionChanged: (selection) =>
                          setState(() => _modeClient = selection.first),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _identifiantController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.username],
                      decoration: InputDecoration(
                        labelText: _modeClient ? 'Email' : 'Téléphone ou email',
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty) ? 'Champ requis' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (value) =>
                          (value == null || value.isEmpty) ? 'Champ requis' : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: isLoading ? null : _submit,
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Se connecter'),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _modeClient
                          ? "Pas encore de compte ? Contactez l'entreprise qui gère "
                              "votre Sabotay."
                          : "Pas encore de compte ? Votre administrateur doit vous "
                              "inviter depuis l'espace web SabotayPro.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
