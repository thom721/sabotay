import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../clients/domain/client.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/recu_pdf.dart';
import '../../transactions/presentation/transaction_providers.dart';
import '../domain/compte_sabotay.dart';
import 'compte_providers.dart';

final _dateFormat = DateFormat('dd/MM/yyyy');
final _amountFormat = NumberFormat.decimalPattern('fr');

/// Tableau de bord d'un compte Sabotay — conversion de
/// Model_Mobil_App/tableau_de_bord_client_sabotaypro : solde disponible en
/// évidence, jours restants/dus, historique filtrable par statut. Écran en
/// lecture seule : la collecte se fait via le numéro de compte depuis le
/// bouton "+" de la page d'accueil (`quick_collecte_sheet.dart`).
class CompteDashboardScreen extends ConsumerWidget {
  final Client client;
  final CompteSabotay compte;

  const CompteDashboardScreen({super.key, required this.client, required this.compte});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final soldeAsync = ref.watch(compteSoldeProvider(compte.id));

    return Scaffold(
      appBar: AppBar(title: Text(client.nomComplet)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(compteSoldeProvider(compte.id));
          ref.invalidate(transactionsForCompteProvider(compte.id));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            soldeAsync.when(
              loading: () => const _HeroCardSkeleton(),
              error: (error, _) => const _ErrorCard(message: 'Solde indisponible'),
              data: (solde) => Column(
                children: [
                  _BalanceHeroCard(solde: solde),
                  const SizedBox(height: 16),
                  _StatCardsRow(compte: compte, solde: solde),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _HistoriqueSection(compte: compte, clientNom: client.nomComplet),
          ],
        ),
      ),
    );
  }
}

class _BalanceHeroCard extends StatelessWidget {
  final CompteSolde solde;

  const _BalanceHeroCard({required this.solde});

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
            'MONTANT COLLECTÉ',
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
              Text(
                'HTG',
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
              ),
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
            label: 'JOURS DUS',
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

class _HistoriqueSection extends ConsumerStatefulWidget {
  final CompteSabotay compte;
  final String clientNom;

  const _HistoriqueSection({required this.compte, required this.clientNom});

  @override
  ConsumerState<_HistoriqueSection> createState() => _HistoriqueSectionState();
}

class _HistoriqueSectionState extends ConsumerState<_HistoriqueSection> {
  TypeTransaction? _filtre;

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsForCompteProvider(widget.compte.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Historique détaillé', style: Theme.of(context).textTheme.titleLarge),
            _FilterToggle(value: _filtre, onChanged: (v) => setState(() => _filtre = v)),
          ],
        ),
        const SizedBox(height: 16),
        transactionsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => const _ErrorCard(message: "Impossible de charger l'historique"),
          data: (transactions) {
            final filtered = _filtre == null
                ? transactions
                : transactions.where((t) => t.type == _filtre).toList();
            if (filtered.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: Text('Aucune transaction trouvée')),
              );
            }
            return Column(
              children: [
                for (final transaction in filtered) ...[
                  _TransactionCard(
                    transaction: transaction,
                    compte: widget.compte,
                    clientNom: widget.clientNom,
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _FilterToggle extends StatelessWidget {
  final TypeTransaction? value;
  final ValueChanged<TypeTransaction?> onChanged;

  const _FilterToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FilterChip(label: 'Tout', selected: value == null, onTap: () => onChanged(null)),
          _FilterChip(
            label: 'Collectes',
            selected: value == TypeTransaction.collecte,
            onTap: () => onChanged(TypeTransaction.collecte),
          ),
          _FilterChip(
            label: 'Retraits',
            selected: value == TypeTransaction.retrait,
            onTap: () => onChanged(TypeTransaction.retrait),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2)]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _TransactionCard extends ConsumerWidget {
  final Transaction transaction;
  final CompteSabotay compte;
  final String clientNom;

  const _TransactionCard({
    required this.transaction,
    required this.compte,
    required this.clientNom,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isRetrait = transaction.type == TypeTransaction.retrait;
    final accent = isRetrait ? colorScheme.tertiary : colorScheme.secondary;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: accent, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isRetrait ? Icons.arrow_upward_rounded : Icons.payments_outlined,
              color: accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRetrait ? 'Retrait' : 'Collecte',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_dateFormat.format(transaction.date)} • ID: #TR-${transaction.id}',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isRetrait ? '- ' : '+ '}${_amountFormat.format(transaction.montant)} HTG',
                style: TextStyle(fontWeight: FontWeight.bold, color: accent),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  typeTransactionLabel(transaction.type).toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: accent),
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined, size: 20),
            tooltip: 'Imprimer le reçu',
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
