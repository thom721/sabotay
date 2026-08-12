import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/change_password_form.dart';
import '../data/client_auth_repository.dart';
import 'client_auth_controller.dart';

/// Équivalent `force_password_change_screen.dart` (Utilisateur) pour le
/// Client — mot de passe temporaire fourni par email à la création du
/// profil, changement obligatoire à la première connexion. Écran nu (pas de
/// shell), même convention que son équivalent staff.
class ClientForcePasswordChangeScreen extends ConsumerWidget {
  const ClientForcePasswordChangeScreen({super.key});

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
                        ref.read(clientAuthRepositoryProvider).changePassword(
                              motDePasseActuel: actuel,
                              nouveauMotDePasse: nouveau,
                            ),
                    onSuccess: () => ref
                        .read(clientAuthControllerProvider.notifier)
                        .refreshCurrentClient(),
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
