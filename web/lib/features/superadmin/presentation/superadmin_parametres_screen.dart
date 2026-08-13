import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/platform_config.dart';
import 'platform_config_controller.dart';
import 'superadmin_auth_controller.dart';
import 'superadmin_scaffold.dart';

/// Réglages globaux de la plateforme, organisés en onglets — un par
/// catégorie de configuration (Abonnement, Email pour l'instant, d'autres
/// pourront s'ajouter ici sans toucher aux existants, voir
/// `PlatformConfigUpdate` côté backend, PATCH partiel). Même esprit que le
/// panneau "Paramètres" de pos_api.
class SuperAdminParametresScreen extends ConsumerStatefulWidget {
  const SuperAdminParametresScreen({super.key});

  @override
  ConsumerState<SuperAdminParametresScreen> createState() =>
      _SuperAdminParametresScreenState();
}

class _SuperAdminParametresScreenState extends ConsumerState<SuperAdminParametresScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(superAdminAuthControllerProvider);

    if (!authState.isLoading && authState.valueOrNull != true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/superadmin/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final configAsync = ref.watch(platformConfigControllerProvider);

    return SuperAdminScaffold(
      title: 'SabotayPro — Paramètres',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.go('/superadmin'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(text: 'Abonnement'),
              Tab(text: 'Email'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 480,
            child: configAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => const Center(child: Text('Impossible de charger les réglages')),
              data: (config) => TabBarView(
                controller: _tabController,
                children: [
                  _AbonnementTab(config: config),
                  _EmailTab(config: config),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AbonnementTab extends ConsumerStatefulWidget {
  final PlatformConfig config;
  const _AbonnementTab({required this.config});

  @override
  ConsumerState<_AbonnementTab> createState() => _AbonnementTabState();
}

class _AbonnementTabState extends ConsumerState<_AbonnementTab> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _montantController;
  late final TextEditingController _essaiController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _montantController =
        TextEditingController(text: widget.config.abonnementMontantHtg.toString());
    _essaiController = TextEditingController(text: widget.config.essaiJours.toString());
  }

  @override
  void dispose() {
    _montantController.dispose();
    _essaiController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(platformConfigControllerProvider.notifier).updateConfig(
            montant: int.parse(_montantController.text),
            essaiJours: int.parse(_essaiController.text),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Réglages abonnement enregistrés')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de mettre à jour les réglages')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Appliqué à toutes les entreprises de la plateforme.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _montantController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Montant abonnement annuel (HTG)'),
              validator: (value) {
                final parsed = int.tryParse(value ?? '');
                if (parsed == null || parsed <= 0) return 'Montant invalide';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _essaiController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Durée de l'essai gratuit (jours)"),
              validator: (value) {
                final parsed = int.tryParse(value ?? '');
                if (parsed == null || parsed <= 0) return 'Nombre de jours invalide';
                return null;
              },
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
                  : const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmailTab extends ConsumerStatefulWidget {
  final PlatformConfig config;
  const _EmailTab({required this.config});

  @override
  ConsumerState<_EmailTab> createState() => _EmailTabState();
}

class _EmailTabState extends ConsumerState<_EmailTab> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _userController;
  late final TextEditingController _passwordController;
  late final TextEditingController _fromController;
  bool _isSaving = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController(text: widget.config.smtpHost ?? '');
    _portController = TextEditingController(text: widget.config.smtpPort.toString());
    _userController = TextEditingController(text: widget.config.smtpUser ?? '');
    _passwordController = TextEditingController();
    _fromController = TextEditingController(text: widget.config.smtpFromEmail ?? '');
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _userController.dispose();
    _passwordController.dispose();
    _fromController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(platformConfigControllerProvider.notifier).updateEmailConfig(
            smtpHost: _hostController.text.trim(),
            smtpPort: int.parse(_portController.text),
            smtpUser: _userController.text.trim(),
            smtpPassword: _passwordController.text,
            smtpFromEmail: _fromController.text.trim(),
          );
      _passwordController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuration email enregistrée')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de mettre à jour la configuration email')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Utilisé pour les emails envoyés par la plateforme (réinitialisation "
              "de mot de passe, notifications). Sans configuration, ces emails "
              "sont simplement journalisés côté serveur, jamais envoyés.",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _hostController,
              decoration: const InputDecoration(
                labelText: 'Serveur SMTP',
                hintText: 'smtp.example.com',
              ),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Champ requis' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _portController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Port'),
              validator: (value) {
                final parsed = int.tryParse(value ?? '');
                if (parsed == null || parsed <= 0) return 'Port invalide';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _userController,
              decoration: const InputDecoration(labelText: "Nom d'utilisateur"),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Champ requis' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: widget.config.smtpPasswordDefini
                    ? 'Mot de passe (laisser vide pour conserver l\'actuel)'
                    : 'Mot de passe',
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (value) {
                if (!widget.config.smtpPasswordDefini && (value == null || value.isEmpty)) {
                  return 'Champ requis';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _fromController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "Adresse d'expédition",
                hintText: 'noreply@sabotaypro.com',
              ),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Champ requis' : null,
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
                  : const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
