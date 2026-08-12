import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/change_password_form.dart';
import '../data/client_auth_repository.dart';
import 'client_auth_controller.dart';
import 'client_nav_drawer.dart';

/// Profil du Client — changement de mot de passe (PRD §8.8, lecture seule
/// sinon). Réutilise `ChangePasswordForm`
/// (`features/auth/presentation/change_password_form.dart`) avec le
/// `ClientAuthRepository` à la place de `AuthRepository`.
class ClientProfilScreen extends ConsumerWidget {
  const ClientProfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(clientAuthControllerProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      drawer: const ClientNavDrawer(),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (client != null) ...[
                    Text(client.nomComplet, style: Theme.of(context).textTheme.titleLarge),
                    if (client.email != null)
                      Text(client.email!, style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 24),
                  ],
                  Text('Changer le mot de passe', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  ChangePasswordForm(
                    onSubmit: (actuel, nouveau) =>
                        ref.read(clientAuthRepositoryProvider).changePassword(
                              motDePasseActuel: actuel,
                              nouveauMotDePasse: nouveau,
                            ),
                    onSuccess: () {
                      ref.read(clientAuthControllerProvider.notifier).refreshCurrentClient();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Mot de passe mis à jour')),
                      );
                    },
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
