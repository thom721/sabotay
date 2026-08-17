import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../data/setup_repository.dart';
import 'setup_providers.dart';

/// Premier écran affiché sur un poste bureau (Epic 5) fraîchement installé,
/// avant tout accès au login normal — voir la garde dans app_router.dart
/// (`setupStatutProvider`). Demande le code d'installation généré côté
/// cloud (Admin → Entreprise → Code d'installation) pour lier ce poste à
/// l'entreprise sans jamais saisir d'identifiants staff sur la machine du
/// client (même principe que le "code d'installation" de pos_api).
class SetupBureauScreen extends ConsumerStatefulWidget {
  const SetupBureauScreen({super.key});

  @override
  ConsumerState<SetupBureauScreen> createState() => _SetupBureauScreenState();
}

class _SetupBureauScreenState extends ConsumerState<SetupBureauScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isSubmitting = false;
  String? _erreur;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _erreur = null;
    });

    try {
      await ref.read(setupRepositoryProvider).connecter(
            code: _codeController.text.trim().toUpperCase(),
            // Fixe, jamais saisi par le client — voir Env.defaultCloudUrl.
            cloudUrl: Env.defaultCloudUrl,
          );
      // Le routeur (app_router.dart) réévalue automatiquement la redirection
      // dès que setupStatutProvider change de valeur — voir _AuthRefreshNotifier.
      ref.invalidate(setupStatutProvider);
    } on DioException catch (e) {
      setState(() => _erreur = _messageErreur(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _messageErreur(DioException e) {
    final detail = e.response?.data is Map ? e.response?.data['detail'] as String? : null;
    if (detail != null) return detail;
    return "Impossible de contacter le cloud — vérifiez l'URL et votre connexion réseau.";
  }

  @override
  Widget build(BuildContext context) {
    // `setupStatutProvider` en erreur = serveur local (pas le cloud)
    // injoignable — la cause la plus probable en pratique (service Windows
    // pas démarré/crashé). Sans ce bandeau, l'agent ne le découvrait qu'en
    // essayant de se connecter et en lisant un message pensé pour un autre
    // cas d'erreur (cloud injoignable) — voir _messageErreur ci-dessus.
    final statutAsync = ref.watch(setupStatutProvider);
    final serveurLocalInjoignable = statutAsync.hasError;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
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
                        const Icon(Icons.dns_outlined, size: 40),
                        const SizedBox(height: 8),
                        Text(
                          'Connecter ce poste au cloud',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Saisissez le code d'installation affiché dans "
                          "Admin → Entreprise sur le cloud de votre entreprise.",
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (serveurLocalInjoignable) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Le serveur local de ce poste ne répond pas.',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onErrorContainer,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Vérifiez que le service "SabotayProServer" est démarré '
                                  '(Services Windows) avant de continuer — la connexion au '
                                  'cloud échouera tant que ce service ne répond pas.',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onErrorContainer,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () => ref.invalidate(setupStatutProvider),
                                    child: const Text('Réessayer'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 32),
                        TextFormField(
                          controller: _codeController,
                          textCapitalization: TextCapitalization.characters,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: "Code d'installation",
                            hintText: 'ABCD-EFGH-IJKL',
                          ),
                          validator: (value) =>
                              (value == null || value.trim().isEmpty) ? 'Champ requis' : null,
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 16),
                        // Fixe, non modifiable par le client — voir
                        // Env.defaultCloudUrl. Affiché en lecture seule
                        // uniquement pour transparence (savoir à quel cloud
                        // ce poste va se connecter), pas comme un champ de
                        // formulaire à remplir.
                        TextFormField(
                          initialValue: Env.defaultCloudUrl,
                          enabled: false,
                          decoration: const InputDecoration(labelText: 'URL du cloud'),
                        ),
                        if (_erreur != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _erreur!,
                            style: TextStyle(color: Theme.of(context).colorScheme.error),
                          ),
                        ],
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _isSubmitting ? null : _submit,
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Connecter'),
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
