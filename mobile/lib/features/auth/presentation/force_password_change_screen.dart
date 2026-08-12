import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import 'auth_controller.dart';
import 'change_password_form.dart';

/// Changement de mot de passe obligatoire (compte créé/réinitialisé par un
/// Admin) — aucune façon de quitter cet écran tant que ce n'est pas fait.
class ForcePasswordChangeScreen extends ConsumerWidget {
  const ForcePasswordChangeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.lock_reset, size: 40, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    'Changez votre mot de passe',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vous devez définir un nouveau mot de passe avant de continuer.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  ChangePasswordForm(
                    onSubmit: (actuel, nouveau) =>
                        ref.read(authRepositoryProvider).changePassword(
                              motDePasseActuel: actuel,
                              nouveauMotDePasse: nouveau,
                            ),
                    onSuccess: () =>
                        ref.read(authControllerProvider.notifier).refreshCurrentUser(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
