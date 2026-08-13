import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../comptes/domain/compte_sabotay.dart';
import '../../transactions/domain/transaction.dart';
import 'client_compte_providers.dart';
import 'client_entreprise_providers.dart';
import 'client_nav_drawer.dart';

final _dateFormat = DateFormat('dd/MM/yyyy');
final _amountFormat = NumberFormat.decimalPattern('fr');

/// Accueil du portail Client (PRD §8.8) : solde, jours restants, jours
/// manqués, aperçu de l'historique. Lecture seule — même calcul de "jours
/// restants" que `compte_dashboard_screen.dart` (`_StatCardsRow`) côté
/// Agent, mais scopé au Client via `clientCompteSoldeProvider`.
class ClientDashboardScreen extends ConsumerWidget {
  const ClientDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comptesAsync = ref.watch(clientMesComptesProvider);
    final entrepriseNom = ref.watch(clientEntrepriseProfilProvider).valueOrNull?.nom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon compte Sabotay'),
        // Seul repère visuel de l'entreprise active — utile dès qu'un
        // client a plusieurs comptes liés (voir `_EntrepriseSelecteur`,
        // `client_nav_drawer.dart`) pour confirmer qu'un changement
        // d'entreprise a bien pris effet.
        bottom: entrepriseNom == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(20),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(entrepriseNom, style: const TextStyle(fontSize: 13)),
                ),
              ),
      ),
      drawer: const ClientNavDrawer(),
      body: comptesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => const Center(child: Text('Impossible de charger vos comptes')),
        data: (comptes) {
          if (comptes.isEmpty) {
            return const Center(child: Text('Aucun compte Sabotay pour le moment'));
          }
          final selectedId = ref.watch(clientCompteSelectionneProvider) ?? comptes.first.id;
          final compte = comptes.firstWhere(
            (c) => c.id == selectedId,
            orElse: () => comptes.first,
          );

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(clientCompteSoldeProvider(compte.id));
              ref.invalidate(clientTransactionsProvider(compte.id));
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (comptes.length > 1) ...[
                  _CompteSelecteur(comptes: comptes, selectedId: compte.id),
                  const SizedBox(height: 16),
                ],
                Consumer(
                  builder: (context, ref, _) {
                    final soldeAsync = ref.watch(clientCompteSoldeProvider(compte.id));
                    return soldeAsync.when(
                      loading: () => const _HeroCardSkeleton(),
                      error: (error, _) => const _ErrorCard(message: 'Solde indisponible'),
                      data: (solde) => Column(
                        children: [
                          _BalanceHeroCard(compte: compte, solde: solde),
                          const SizedBox(height: 16),
                          _StatCardsRow(compte: compte, solde: solde),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text('Dernières transactions', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Consumer(
                  builder: (context, ref, _) {
                    final transactionsAsync = ref.watch(clientTransactionsProvider(compte.id));
                    return transactionsAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (error, _) => const Text("Impossible de charger l'historique"),
                      data: (transactions) => transactions.isEmpty
                          ? const Text('Aucune transaction pour le moment')
                          : Column(
                              children: [
                                for (final transaction in transactions.take(5))
                                  _TransactionPreviewTile(transaction: transaction),
                              ],
                            ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CompteSelecteur extends ConsumerWidget {
  final List<CompteSabotay> comptes;
  final String selectedId;

  const _CompteSelecteur({required this.comptes, required this.selectedId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DropdownButtonFormField<String>(
      value: selectedId,
      decoration: const InputDecoration(labelText: 'Compte'),
      items: [
        for (final compte in comptes)
          DropdownMenuItem(value: compte.id, child: Text(compte.numeroCompte)),
      ],
      onChanged: (value) =>
          ref.read(clientCompteSelectionneProvider.notifier).state = value,
    );
  }
}

class _BalanceHeroCard extends StatelessWidget {
  final CompteSabotay compte;
  final CompteSolde solde;

  const _BalanceHeroCard({required this.compte, required this.solde});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorScheme.primary, const Color(0xFF191C1E)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SOLDE COLLECTÉ',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _amountFormat.format(solde.montantCollecte),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 8),
              Text('HTG', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'sur ${_amountFormat.format(solde.montantTotalAttendu)} HTG attendus',
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _StatCardsRow extends StatelessWidget {
  final CompteSabotay compte;
  final CompteSolde solde;

  const _StatCardsRow({required this.compte, required this.solde});

  @override
  Widget build(BuildContext context) {
    final joursRestants = compte.dateFinPrevue.difference(DateTime.now()).inDays;
    final progress = compte.dureeJours == 0
        ? 0.0
        : (1 - joursRestants / compte.dureeJours).clamp(0, 1).toDouble();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.event_outlined,
            label: 'JOURS RESTANTS',
            value: '${joursRestants < 0 ? 0 : joursRestants} jours',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            icon: Icons.warning_amber_rounded,
            iconColor: Theme.of(context).colorScheme.error,
            iconBg: Theme.of(context).colorScheme.errorContainer,
            label: 'JOURS MANQUÉS',
            value: '${solde.joursManques} jours',
            valueColor: solde.joursManques > 0 ? Theme.of(context).colorScheme.error : null,
            child: solde.dette > 0
                ? Text(
                    'Dette : ${_amountFormat.format(solde.dette)} HTG',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final Color? iconBg;
  final String label;
  final String value;
  final Color? valueColor;
  final Widget? child;

  const _StatCard({
    required this.icon,
    this.iconColor,
    this.iconBg,
    required this.label,
    required this.value,
    this.valueColor,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg ?? colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: iconColor ?? colorScheme.primary),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: valueColor ?? colorScheme.onSurface,
            ),
          ),
          if (child != null) ...[const SizedBox(height: 8), child!],
        ],
      ),
    );
  }
}

class _TransactionPreviewTile extends StatelessWidget {
  final Transaction transaction;

  const _TransactionPreviewTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isRetrait = transaction.type == TypeTransaction.retrait;
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isRetrait ? Icons.arrow_upward : Icons.check_circle_outline,
        color: isRetrait ? colorScheme.tertiary : colorScheme.secondary,
      ),
      title: Text('${_amountFormat.format(transaction.montant)} HTG'),
      subtitle: Text(_dateFormat.format(transaction.date)),
    );
  }
}

class _HeroCardSkeleton extends StatelessWidget {
  const _HeroCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(child: Text(message)),
    );
  }
}
