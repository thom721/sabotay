import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'superadmin_auth_controller.dart';

/// Création du tout premier compte super-admin — affiché à la place de
/// [SuperAdminLoginScreen] uniquement tant qu'aucun compte n'existe encore
/// (voir `superAdminBootstrapNecessaireProvider`), c'est-à-dire au tout
/// premier déploiement cloud. Verrouillé définitivement côté backend dès
/// qu'un compte a été créé — revenir sur cette route ensuite redirige vers
/// le login normal.
class SuperAdminBootstrapScreen extends ConsumerStatefulWidget {
  const SuperAdminBootstrapScreen({super.key});

  @override
  ConsumerState<SuperAdminBootstrapScreen> createState() => _SuperAdminBootstrapScreenState();
}

class _SuperAdminBootstrapScreenState extends ConsumerState<SuperAdminBootstrapScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nomController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(superAdminAuthControllerProvider.notifier).bootstrapPremierCompte(
          nom: _nomController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
    final loggedIn = ref.read(superAdminAuthControllerProvider).valueOrNull == true;
    if (loggedIn && mounted) {
      context.go('/superadmin');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Un compte existe déjà (accès direct à cette route après le tout
    // premier déploiement, ou rechargement après création) : plus aucune
    // raison d'être ici, retour au login normal.
    final bootstrapState = ref.watch(superAdminBootstrapNecessaireProvider);
    if (bootstrapState.valueOrNull == false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/superadmin/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final authState = ref.watch(superAdminAuthControllerProvider);
    final isLoading = authState.isLoading;

    ref.listen(superAdminAuthControllerProvider, (previous, next) {
      if (next.hasError && !next.isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de créer ce compte — réessayez.')),
        );
      }
    });

    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.admin_panel_settings, size: 40),
                        const SizedBox(height: 8),
                        Text(
                          'Premier déploiement — créer le compte administrateur plateforme',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Cet écran ne s'affiche qu'une seule fois : dès ce "
                          "compte créé, la connexion habituelle prendra le relais.",
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 32),
                        TextFormField(
                          controller: _nomController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'Nom'),
                          validator: (value) =>
                              (value == null || value.trim().isEmpty) ? 'Champ requis' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.username],
                          decoration: const InputDecoration(labelText: 'Email'),
                          validator: (value) =>
                              (value == null || value.trim().isEmpty) ? 'Champ requis' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.newPassword],
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
                          validator: (value) => (value == null || value.length < 8)
                              ? 'Au moins 8 caractères'
                              : null,
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
                              : const Text('Créer le compte'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
