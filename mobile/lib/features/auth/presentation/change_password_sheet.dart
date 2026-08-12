import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import 'change_password_form.dart';

/// Changement de mot de passe volontaire (bouton profil de l'accueil) —
/// contrairement à `force_password_change_screen.dart`, l'utilisateur peut
/// fermer ce sheet sans rien changer.
Future<void> showChangePasswordSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _ChangePasswordSheet(),
  );
}

class _ChangePasswordSheet extends ConsumerWidget {
  const _ChangePasswordSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Changer le mot de passe', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          ChangePasswordForm(
            onSubmit: (actuel, nouveau) => ref.read(authRepositoryProvider).changePassword(
                  motDePasseActuel: actuel,
                  nouveauMotDePasse: nouveau,
                ),
            onSuccess: () {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.of(context).pop();
              messenger.showSnackBar(
                const SnackBar(content: Text('Mot de passe mis à jour')),
              );
            },
          ),
        ],
      ),
    );
  }
}
