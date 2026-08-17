import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_state_views.dart';
import '../../../core/widgets/dashboard_shell.dart';
import '../../auth/domain/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../comptes/domain/compte_sabotay.dart';
import '../../comptes/presentation/compte_providers.dart';
import '../../comptes/presentation/create_compte_sheet.dart';
import '../../transactions/presentation/add_collecte_sheet.dart';
import '../../transactions/presentation/retrait_sheet.dart';
import '../domain/client.dart';
import 'client_list_controller.dart';

final _dateFormat = DateFormat('dd/MM/yyyy');
final _lastLoginFormat = DateFormat('dd/MM/yyyy HH:mm');
final _montantFormat = NumberFormat('#,##0.##');

/// Fiche détaillée d'un client : infos de contact et comptes Sabotay
/// associés, avec création d'un nouveau compte (PRD §8.4).
class ClientDetailScreen extends ConsumerWidget {
  final String clientId;
  const ClientDetailScreen({super.key, required this.clientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientAsync = ref.watch(clientDetailProvider(clientId));
    final comptesAsync = ref.watch(clientComptesProvider(clientId));
    final role = ref.watch(authControllerProvider).valueOrNull?.role;
    // Création de compte réservée à Admin/Manager côté backend
    // (`POST /comptes`, require_roles ADMIN/MANAGER) — un Agent ne fixe pas
    // les termes commerciaux d'un compte, il collecte seulement dessus.
    final peutCreerCompte = role == RoleUtilisateur.admin || role == RoleUtilisateur.manager;

    return DashboardContent(
      title: clientAsync.valueOrNull?.nomComplet ?? 'Client',
      backgroundColor: const Color(0xFFF0F2F5),
      action: peutCreerCompte
          ? ElevatedButton.icon(
              onPressed: () => showCreateCompteSheet(context, clientId),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nouveau compte'),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          clientAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => ErrorState(
              message: 'Impossible de charger le client',
              onRetry: () => ref.invalidate(clientDetailProvider(clientId)),
            ),
            data: (client) => _ClientInfoCard(client: client),
          ),
          const SizedBox(height: 24),
          Text('Comptes Sabotay', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          comptesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => ErrorState(
              message: 'Impossible de charger les comptes',
              onRetry: () => ref.invalidate(clientComptesProvider(clientId)),
            ),
            data: (comptes) => comptes.isEmpty
                ? const EmptyState(message: 'Aucun compte Sabotay pour ce client')
                : Column(
                    children: [
                      for (final compte in comptes) ...[
                        _CompteCard(
                          compte: compte,
                          clientNom: clientAsync.valueOrNull?.nomComplet,
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ClientInfoCard extends StatelessWidget {
  final Client client;
  const _ClientInfoCard({required this.client});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final actif = client.statut == StatutClient.actif;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: colorScheme.primary,
                  child: Text(
                    client.prenom.isNotEmpty ? client.prenom[0].toUpperCase() : '?',
                    style: TextStyle(color: colorScheme.onPrimary, fontSize: 18),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(client.nomComplet, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(client.telephone, style: TextStyle(color: colorScheme.onSurfaceVariant)),
                      if (client.adresse != null && client.adresse!.isNotEmpty)
                        Text(client.adresse!, style: TextStyle(color: colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                _StatutChip(
                  label: actif ? 'Actif' : 'Inactif',
                  color: actif ? colorScheme.secondary : colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            if (client.email != null ||
                client.nifCin != null ||
                client.dateNaissance != null) ...[
              const Divider(height: 24),
              Wrap(
                spacing: 24,
                runSpacing: 8,
                children: [
                  if (client.email != null && client.email!.isNotEmpty)
                    _InfoField(label: 'Email', value: client.email!),
                  if (client.nifCin != null && client.nifCin!.isNotEmpty)
                    _InfoField(label: 'NIF/CIN', value: client.nifCin!),
                  if (client.dateNaissance != null)
                    _InfoField(
                      label: 'Date de naissance',
                      value: _dateFormat.format(client.dateNaissance!),
                    ),
                ],
              ),
            ],
            const Divider(height: 24),
            _InfoField(
              label: 'Dernière connexion',
              value: client.derniereConnexion == null
                  ? 'Jamais connecté'
                  : _lastLoginFormat.format(client.derniereConnexion!),
            ),
            if (client.aHeritier) ...[
              const Divider(height: 24),
              Text('Héritier (bénéficiaire)', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 24,
                runSpacing: 8,
                children: [
                  if ((client.heritierPrenom ?? '').isNotEmpty || (client.heritierNom ?? '').isNotEmpty)
                    _InfoField(
                      label: 'Nom',
                      value: '${client.heritierPrenom ?? ''} ${client.heritierNom ?? ''}'.trim(),
                    ),
                  if (client.heritierTelephone != null && client.heritierTelephone!.isNotEmpty)
                    _InfoField(label: 'Téléphone', value: client.heritierTelephone!),
                  if (client.heritierAdresse != null && client.heritierAdresse!.isNotEmpty)
                    _InfoField(label: 'Adresse', value: client.heritierAdresse!),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoField extends StatelessWidget {
  final String label;
  final String value;
  const _InfoField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _CompteCard extends ConsumerWidget {
  final CompteSabotay compte;
  final String? clientNom;
  const _CompteCard({required this.compte, this.clientNom});

  Color _statutColor(ColorScheme colorScheme, StatutCompte statut) => switch (statut) {
        StatutCompte.actif => colorScheme.secondary,
        StatutCompte.enRetard => colorScheme.error,
        StatutCompte.complete => colorScheme.onSurfaceVariant,
        StatutCompte.annule => colorScheme.onSurfaceVariant,
        StatutCompte.inactif => colorScheme.onSurfaceVariant,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final soldeAsync = ref.watch(compteSoldeProvider(compte.id));

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_montantFormat.format(compte.montantJournalier)} HTG / jour',
                  style: AppTheme.statNumberStyle(context, fontSize: 20),
                ),
                _StatutChip(
                  label: statutCompteLabel(compte.statut),
                  color: _statutColor(colorScheme, compte.statut),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${_dateFormat.format(compte.dateDebut)} → ${_dateFormat.format(compte.dateFinPrevue)}'
              ' · ${compte.dureeJours} jours',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              'Montant total attendu : ${_montantFormat.format(compte.montantTotalAttendu)} HTG',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const Divider(height: 24),
            soldeAsync.when(
              loading: () => const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (error, _) => const SizedBox.shrink(),
              data: (solde) => Wrap(
                spacing: 24,
                runSpacing: 8,
                children: [
                  _SoldeStat(label: 'Collecté', value: '${_montantFormat.format(solde.montantCollecte)} HTG'),
                  _SoldeStat(label: 'Solde restant', value: '${_montantFormat.format(solde.soldeRestant)} HTG'),
                  _SoldeStat(label: 'Dette', value: '${_montantFormat.format(solde.dette)} HTG'),
                  _SoldeStat(label: 'Jours manqués', value: '${solde.joursManques}'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => showAddCollecteSheet(context, compte, clientNom: clientNom),
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Collecter'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => showRetraitSheet(context, compte, clientNom: clientNom),
                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                    label: const Text('Retirer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SoldeStat extends StatelessWidget {
  final String label;
  final String value;
  const _SoldeStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _StatutChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatutChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.4),
      ),
    );
  }
}
