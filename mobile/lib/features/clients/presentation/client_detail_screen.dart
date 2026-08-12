import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../comptes/domain/compte_sabotay.dart';
import '../../comptes/presentation/compte_dashboard_screen.dart';
import '../../comptes/presentation/compte_providers.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/recu_pdf.dart';
import '../../transactions/presentation/transaction_providers.dart';
import '../domain/client.dart';

final _dateFormat = DateFormat('dd/MM/yyyy');
final _amountFormat = NumberFormat.decimalPattern('fr');

/// Écran de détail d'un client : ses infos, ses comptes Sabotay, le solde de
/// chaque compte et l'historique des collectes — en lecture seule. La
/// collecte se fait uniquement via le numéro de compte, depuis le bouton "+"
/// de la page d'accueil (`quick_collecte_sheet.dart`), pour éviter toute
/// erreur de sélection de client/compte.
class ClientDetailScreen extends ConsumerWidget {
  final Client client;

  const ClientDetailScreen({super.key, required this.client});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comptesAsync = ref.watch(comptesForClientProvider(client.id));

    return Scaffold(
      appBar: AppBar(title: Text(client.nomComplet)),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(comptesForClientProvider(client.id)),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ClientInfoCard(client: client),
            const SizedBox(height: 24),
            Text('Comptes Sabotay', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            comptesAsync.when(
              loading: () => const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(),
              )),
              error: (error, _) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Impossible de charger les comptes Sabotay'),
              ),
              data: (comptes) => comptes.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('Aucun compte Sabotay pour ce client'),
                    )
                  : Column(
                      children: [
                        for (final compte in comptes) ...[
                          InkWell(
                            borderRadius: BorderRadius.circular(4),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    CompteDashboardScreen(client: client, compte: compte),
                              ),
                            ),
                            child: _CompteCard(compte: compte, clientNom: client.nomComplet),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientInfoCard extends StatelessWidget {
  final Client client;

  const _ClientInfoCard({required this.client});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(client.nomComplet, style: Theme.of(context).textTheme.titleMedium),
                ),
                Chip(
                  label: Text(client.statut == StatutClient.actif ? 'Actif' : 'Inactif'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _InfoRow(icon: Icons.phone, label: client.telephone),
            if (client.adresse != null && client.adresse!.isNotEmpty)
              _InfoRow(icon: Icons.location_on_outlined, label: client.adresse!),
            if (client.email != null && client.email!.isNotEmpty)
              _InfoRow(icon: Icons.email_outlined, label: client.email!),
            if (client.dateNaissance != null)
              _InfoRow(
                icon: Icons.cake_outlined,
                label: 'Né(e) le ${_dateFormat.format(client.dateNaissance!)}',
              ),
            if (client.nifCin != null && client.nifCin!.isNotEmpty)
              _InfoRow(icon: Icons.badge_outlined, label: 'NIF/CIN : ${client.nifCin!}'),
            if (client.agentAssigneId != null)
              _InfoRow(
                icon: Icons.support_agent_outlined,
                label: 'Agent assigné : #${client.agentAssigneId}',
              ),
            if (client.derniereConnexion != null)
              _InfoRow(
                icon: Icons.login,
                label: 'Dernière connexion : ${_dateFormat.format(client.derniereConnexion!)}',
              ),
            if (client.aHeritier) ...[
              const Divider(height: 20),
              Text('Héritier', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              _InfoRow(
                icon: Icons.person_outline,
                label: '${client.heritierPrenom ?? ''} ${client.heritierNom ?? ''}'.trim(),
              ),
              if (client.heritierTelephone != null && client.heritierTelephone!.isNotEmpty)
                _InfoRow(icon: Icons.phone_outlined, label: client.heritierTelephone!),
              if (client.heritierAdresse != null && client.heritierAdresse!.isNotEmpty)
                _InfoRow(icon: Icons.location_on_outlined, label: client.heritierAdresse!),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class _CompteCard extends ConsumerWidget {
  final CompteSabotay compte;
  final String clientNom;

  const _CompteCard({required this.compte, required this.clientNom});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final soldeAsync = ref.watch(compteSoldeProvider(compte.id));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    compte.numeroCompte,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                  ),
                ),
                _StatutCompteChip(statut: compte.statut),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${_amountFormat.format(compte.montantJournalier)} HTG / jour',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              '${_dateFormat.format(compte.dateDebut)} → ${_dateFormat.format(compte.dateFinPrevue)}'
              ' · ${compte.dureeJours} jours',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            soldeAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => const Text('Solde indisponible'),
              data: (solde) => _SoldeSection(solde: solde),
            ),
            const SizedBox(height: 12),
            _TransactionsSection(compte: compte, clientNom: clientNom),
          ],
        ),
      ),
    );
  }
}

class _SoldeSection extends StatelessWidget {
  final CompteSolde solde;

  const _SoldeSection({required this.solde});

  @override
  Widget build(BuildContext context) {
    final progress = solde.montantTotalAttendu == 0
        ? 0.0
        : (solde.montantCollecte / solde.montantTotalAttendu).clamp(0, 1).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: progress, minHeight: 6),
        ),
        const SizedBox(height: 6),
        Text(
          '${_amountFormat.format(solde.montantCollecte)} / '
          '${_amountFormat.format(solde.montantTotalAttendu)} HTG collectés',
          style: const TextStyle(fontSize: 12),
        ),
        if (solde.dette > 0)
          Text(
            'Dette : ${_amountFormat.format(solde.dette)} HTG',
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.error),
          ),
        if (solde.joursManques > 0)
          Text(
            '${solde.joursManques} jour(s) manqué(s)',
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }
}

class _StatutCompteChip extends StatelessWidget {
  final StatutCompte statut;

  const _StatutCompteChip({required this.statut});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = switch (statut) {
      StatutCompte.actif => colorScheme.secondary,
      StatutCompte.enRetard => colorScheme.error,
      StatutCompte.complete => colorScheme.primary,
      StatutCompte.annule => colorScheme.onSurfaceVariant,
      StatutCompte.inactif => colorScheme.onSurfaceVariant,
    };
    return Chip(
      label: Text(statutCompteLabel(statut)),
      labelStyle: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      visualDensity: VisualDensity.compact,
      backgroundColor: color.withOpacity(0.12),
      side: BorderSide.none,
    );
  }
}

class _TransactionsSection extends ConsumerWidget {
  final CompteSabotay compte;
  final String clientNom;

  const _TransactionsSection({required this.compte, required this.clientNom});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsForCompteProvider(compte.id));

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text('Historique des collectes', style: TextStyle(fontSize: 13)),
      childrenPadding: const EdgeInsets.only(bottom: 8),
      children: [
        transactionsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (error, _) => const Text('Impossible de charger l\'historique'),
          data: (transactions) => transactions.isEmpty
              ? const Text('Aucune collecte enregistrée')
              : Column(
                  children: [
                    for (final transaction in transactions)
                      _TransactionTile(transaction: transaction, compte: compte, clientNom: clientNom),
                  ],
                ),
        ),
      ],
    );
  }
}

class _TransactionTile extends ConsumerWidget {
  final Transaction transaction;
  final CompteSabotay compte;
  final String clientNom;

  const _TransactionTile({
    required this.transaction,
    required this.compte,
    required this.clientNom,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRetrait = transaction.type == TypeTransaction.retrait;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isRetrait ? Icons.arrow_upward : Icons.check_circle_outline,
            size: 16,
            color: isRetrait ? colorScheme.tertiary : colorScheme.secondary,
          ),
          const SizedBox(width: 8),
          Text(_dateFormat.format(transaction.date), style: const TextStyle(fontSize: 12)),
          if (isRetrait) ...[
            const SizedBox(width: 6),
            Text(
              'Retrait',
              style: TextStyle(fontSize: 11, color: colorScheme.tertiary, fontWeight: FontWeight.w600),
            ),
          ],
          const Spacer(),
          Text(
            '${_amountFormat.format(transaction.montant)} HTG',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined, size: 18),
            tooltip: 'Imprimer le reçu',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () => imprimerRecu(
              context,
              ref,
              transaction: transaction,
              compte: compte,
              clientNom: clientNom,
            ),
          ),
        ],
      ),
    );
  }
}
