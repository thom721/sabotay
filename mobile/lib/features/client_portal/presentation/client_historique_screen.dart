import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../comptes/domain/compte_sabotay.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/recu_pdf.dart';
import 'client_auth_controller.dart';
import 'client_compte_providers.dart';
import 'client_entreprise_providers.dart';
import 'client_nav_drawer.dart';

final _dateFormat = DateFormat('dd/MM/yyyy');
final _amountFormat = NumberFormat.decimalPattern('fr');

/// Historique complet du compte Sabotay du Client, avec impression de reçu
/// par ligne (PRD §8.8) — réutilise `imprimerRecu` telle quelle
/// (`transactions/presentation/recu_pdf.dart`), indépendante du rôle de qui
/// l'appelle.
class ClientHistoriqueScreen extends ConsumerWidget {
  const ClientHistoriqueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comptesAsync = ref.watch(clientMesComptesProvider);
    final client = ref.watch(clientAuthControllerProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Historique')),
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
          final transactionsAsync = ref.watch(clientTransactionsProvider(compte.id));

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(clientTransactionsProvider(compte.id)),
            child: transactionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => const Center(child: Text("Impossible de charger l'historique")),
              data: (transactions) => transactions.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('Aucune transaction pour le moment')),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: transactions.length,
                      itemBuilder: (context, index) => _TransactionCard(
                        transaction: transactions[index],
                        compte: compte,
                        clientNom: client?.nomComplet ?? '',
                      ),
                    ),
            ),
          );
        },
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
    final isRetrait = transaction.type == TypeTransaction.retrait;
    final colorScheme = Theme.of(context).colorScheme;
    final accent = isRetrait ? colorScheme.tertiary : colorScheme.secondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
            decoration: BoxDecoration(color: accent.withOpacity(0.12), shape: BoxShape.circle),
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
          Text(
            '${isRetrait ? '- ' : '+ '}${_amountFormat.format(transaction.montant)} HTG',
            style: TextStyle(fontWeight: FontWeight.bold, color: accent),
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined, size: 20),
            tooltip: 'Imprimer le reçu',
            onPressed: () async {
              final entreprise = await ref.read(clientEntrepriseProfilProvider.future);
              if (context.mounted) {
                imprimerRecu(
                  context,
                  ref,
                  transaction: transaction,
                  compte: compte,
                  clientNom: clientNom,
                  entreprise: entreprise,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
