import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/async_state_views.dart';
import '../domain/superadmin_compte.dart';
import 'create_superadmin_compte_sheet.dart';
import 'superadmin_auth_controller.dart';
import 'superadmin_comptes_controller.dart';
import 'superadmin_scaffold.dart';

final _lastLoginFormat = DateFormat('dd/MM/yyyy HH:mm');

String _formatDerniereConnexion(String? derniereConnexion) {
  if (derniereConnexion == null) return 'Jamais connecté';
  final parsed = DateTime.tryParse(derniereConnexion);
  if (parsed == null) return 'Dernière connexion : $derniereConnexion';
  return 'Dernière connexion : ${_lastLoginFormat.format(parsed)}';
}

/// Gestion des comptes super-admin de la plateforme — réservée au
/// super-admin. Comme [SuperAdminEntreprisesScreen], cet écran vérifie
/// lui-même la session (le routeur ne protège pas `/superadmin/*`).
class SuperAdminComptesScreen extends ConsumerStatefulWidget {
  const SuperAdminComptesScreen({super.key});

  @override
  ConsumerState<SuperAdminComptesScreen> createState() => _SuperAdminComptesScreenState();
}

class _SuperAdminComptesScreenState extends ConsumerState<SuperAdminComptesScreen> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(superAdminAuthControllerProvider);

    if (!authState.isLoading && authState.valueOrNull != true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/superadmin/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final comptesAsync = ref.watch(superAdminComptesControllerProvider);
    final selfIdAsync = ref.watch(superAdminSelfIdProvider);

    return SuperAdminScaffold(
      title: 'SabotayPro — Comptes admin',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.go('/superadmin'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Comptes super-admin',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Actualiser',
                onPressed: () =>
                    ref.read(superAdminComptesControllerProvider.notifier).refresh(),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => showCreateSuperAdminCompteSheet(context),
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('Ajouter un compte'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          comptesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => ErrorState(
              message: 'Impossible de charger les comptes',
              onRetry: () => ref.read(superAdminComptesControllerProvider.notifier).refresh(),
            ),
            data: (comptes) => comptes.isEmpty
                ? const EmptyState(message: 'Aucun compte pour l\'instant')
                : Card(
                    margin: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < comptes.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          _CompteRow(
                            compte: comptes[i],
                            isSelf: selfIdAsync.valueOrNull == comptes[i].id,
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CompteRow extends ConsumerWidget {
  final SuperAdminCompte compte;
  final bool isSelf;

  const _CompteRow({required this.compte, required this.isSelf});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isActif = compte.statut == 'actif';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: colorScheme.primary,
        child: Text(
          compte.nom.isNotEmpty ? compte.nom[0].toUpperCase() : '?',
          style: TextStyle(color: colorScheme.onPrimary),
        ),
      ),
      title: Text(compte.nom),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(compte.email),
          Text(
            _formatDerniereConnexion(compte.derniereConnexion),
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Chip(
            label: Text(isActif ? 'Actif' : 'Inactif'),
            backgroundColor:
                (isActif ? Colors.green : Colors.grey).withOpacity(0.12),
            labelStyle: TextStyle(
              color: isActif ? Colors.green.shade800 : Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: isSelf ? 'Vous ne pouvez pas désactiver votre propre compte' : '',
            child: Switch(
              value: isActif,
              onChanged: isSelf
                  ? null
                  : (_) =>
                      ref.read(superAdminComptesControllerProvider.notifier).toggleStatut(compte),
            ),
          ),
        ],
      ),
    );
  }
}
