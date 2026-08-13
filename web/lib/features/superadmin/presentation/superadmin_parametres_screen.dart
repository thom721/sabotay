import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/async_state_views.dart';
import '../../abonnement/domain/paiement_abonnement.dart';
import '../data/superadmin_repository.dart';
import '../domain/platform_config.dart';
import 'platform_config_controller.dart';
import 'superadmin_auth_controller.dart';
import 'superadmin_scaffold.dart';

final _paiementsEnAttenteProvider = FutureProvider<List<PaiementEnAttente>>((ref) {
  return ref.watch(superAdminRepositoryProvider).fetchPaiementsEnAttente();
});

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
    _tabController = TabController(length: 3, vsync: this);
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
              Tab(text: 'SMTP Config'),
              Tab(text: 'Paiements en attente'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 480,
            child: TabBarView(
              controller: _tabController,
              children: [
                configAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) =>
                      const Center(child: Text('Impossible de charger les réglages')),
                  data: (config) => _AbonnementTab(config: config),
                ),
                configAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) =>
                      const Center(child: Text('Impossible de charger les réglages')),
                  data: (config) => _EmailTab(config: config),
                ),
                const _PaiementsEnAttenteTab(),
              ],
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
            Card(
              color: Colors.white,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tarification', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final montantField = TextFormField(
                          controller: _montantController,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Montant abonnement annuel (HTG)'),
                          validator: (value) {
                            final parsed = int.tryParse(value ?? '');
                            if (parsed == null || parsed <= 0) return 'Montant invalide';
                            return null;
                          },
                        );
                        final essaiField = TextFormField(
                          controller: _essaiController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "Durée de l'essai gratuit (jours)",
                          ),
                          validator: (value) {
                            final parsed = int.tryParse(value ?? '');
                            if (parsed == null || parsed <= 0) return 'Nombre de jours invalide';
                            return null;
                          },
                        );
                        if (constraints.maxWidth < 480) {
                          return Column(
                            children: [
                              montantField,
                              const SizedBox(height: 16),
                              essaiField,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: montantField),
                            const SizedBox(width: 16),
                            Expanded(child: essaiField),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
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
            Card(
              color: Colors.white,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Configuration SMTP', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
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
                        if (!widget.config.smtpPasswordDefini &&
                            (value == null || value.isEmpty)) {
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
                  ],
                ),
              ),
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

final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');
final _montantFormat = NumberFormat('#,##0.##');

/// Paiements espèces en attente de confirmation, toutes entreprises
/// confondues — la seule vue permettant de retrouver une déclaration sans
/// savoir déjà de quelle entreprise elle vient (voir aussi la fiche détail
/// d'une entreprise, qui montre les siens seulement).
class _PaiementsEnAttenteTab extends ConsumerWidget {
  const _PaiementsEnAttenteTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paiementsAsync = ref.watch(_paiementsEnAttenteProvider);

    return paiementsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorState(
        message: 'Impossible de charger les paiements en attente',
        onRetry: () => ref.invalidate(_paiementsEnAttenteProvider),
      ),
      data: (paiements) => paiements.isEmpty
          ? const EmptyState(message: 'Aucun paiement en attente')
          : ListView.separated(
              itemCount: paiements.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) => _PaiementEnAttenteTile(paiement: paiements[i]),
            ),
    );
  }
}

class _PaiementEnAttenteTile extends ConsumerStatefulWidget {
  final PaiementEnAttente paiement;
  const _PaiementEnAttenteTile({required this.paiement});

  @override
  ConsumerState<_PaiementEnAttenteTile> createState() => _PaiementEnAttenteTileState();
}

class _PaiementEnAttenteTileState extends ConsumerState<_PaiementEnAttenteTile> {
  bool _isProcessing = false;

  Future<void> _traiter(Future<void> Function() action) async {
    setState(() => _isProcessing = true);
    try {
      await action();
      ref.invalidate(_paiementsEnAttenteProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Action impossible. Réessayez plus tard.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final paiement = widget.paiement;

    return ListTile(
      title: Text(paiement.entrepriseNom),
      subtitle: Text(
        '${_montantFormat.format(paiement.montant)} HTG — '
        '${_dateFormat.format(paiement.datePaiement)}'
        '${paiement.payeParNom != null ? ' — déclaré par ${paiement.payeParNom}' : ''}',
      ),
      trailing: _isProcessing
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Rejeter',
                  onPressed: () => _traiter(
                    () => ref.read(superAdminRepositoryProvider).rejeterPaiement(paiement.id),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.check),
                  tooltip: 'Confirmer',
                  onPressed: () => _traiter(
                    () => ref.read(superAdminRepositoryProvider).confirmerPaiement(paiement.id),
                  ),
                ),
              ],
            ),
    );
  }
}
