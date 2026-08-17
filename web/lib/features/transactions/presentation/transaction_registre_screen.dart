import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/async_state_views.dart';
import '../../../core/widgets/dashboard_shell.dart';
import '../../entreprise/data/entreprise_repository.dart';
import '../data/transaction_repository.dart';
import '../domain/transaction.dart';
import 'recu_pdf.dart';

final _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
final _montantFormat = NumberFormat.decimalPattern('fr');

const _pageSize = 50;

/// Registre brut de toutes les transactions — recherche libre par
/// client/compte/agent, paginé, sans période par défaut. Complète l'onglet
/// "Rapports" (synthèse + totaux sur une période) : celui-ci sert à
/// retrouver UNE transaction précise sans avoir à connaître sa date.
class TransactionRegistreScreen extends ConsumerStatefulWidget {
  const TransactionRegistreScreen({super.key});

  @override
  ConsumerState<TransactionRegistreScreen> createState() => _TransactionRegistreScreenState();
}

class _TransactionRegistreScreenState extends ConsumerState<TransactionRegistreScreen> {
  final _rechercheController = TextEditingController();
  Timer? _debounce;
  String _q = '';
  int _skip = 0;
  Future<RegistrePage>? _pageFuture;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _rechercheController.dispose();
    super.dispose();
  }

  void _charger() {
    setState(() {
      _pageFuture = ref.read(transactionRepositoryProvider).getRegistre(
            q: _q,
            skip: _skip,
            limit: _pageSize,
          );
    });
  }

  void _onRechercheChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() {
        _q = value;
        _skip = 0;
      });
      _charger();
    });
  }

  void _pagePrecedente() {
    setState(() => _skip = (_skip - _pageSize).clamp(0, 1 << 30));
    _charger();
  }

  void _pageSuivante(int total) {
    if (_skip + _pageSize >= total) return;
    setState(() => _skip += _pageSize);
    _charger();
  }

  @override
  Widget build(BuildContext context) {
    return DashboardContent(
      title: 'Transactions',
      backgroundColor: const Color(0xFFF0F2F5),
      action: IconButton(
        icon: const Icon(Icons.refresh),
        tooltip: 'Actualiser',
        onPressed: _charger,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 400,
            child: TextField(
              controller: _rechercheController,
              decoration: const InputDecoration(
                hintText: 'Rechercher par client, n° de compte ou agent',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
              ),
              onChanged: _onRechercheChanged,
            ),
          ),
          const SizedBox(height: 20),
          FutureBuilder<RegistrePage>(
            future: _pageFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return ErrorState(message: 'Impossible de charger les transactions', onRetry: _charger);
              }
              final page = snapshot.data;
              if (page == null) return const SizedBox.shrink();
              if (page.items.isEmpty) {
                return EmptyState(
                  message: _q.isEmpty
                      ? 'Aucune transaction pour l\'instant'
                      : 'Aucune transaction ne correspond à cette recherche',
                );
              }
              return _RegistreContent(
                page: page,
                skip: _skip,
                onPrecedent: _skip > 0 ? _pagePrecedente : null,
                onSuivant: _skip + _pageSize < page.total ? () => _pageSuivante(page.total) : null,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RegistreContent extends ConsumerWidget {
  final RegistrePage page;
  final int skip;
  final VoidCallback? onPrecedent;
  final VoidCallback? onSuivant;

  const _RegistreContent({
    required this.page,
    required this.skip,
    required this.onPrecedent,
    required this.onSuivant,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entrepriseAsync = ref.watch(entrepriseProfileProvider);
    final devise = entrepriseAsync.valueOrNull?.devise ?? '';
    final debut = skip + 1;
    final fin = (skip + page.items.length).clamp(0, page.total);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < page.items.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _RegistreRow(item: page.items[i], devise: devise),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$debut–$fin sur ${page.total}',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
            ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onPrecedent,
                  icon: const Icon(Icons.chevron_left, size: 18),
                  label: const Text('Précédent'),
                ),
                TextButton.icon(
                  onPressed: onSuivant,
                  icon: const Icon(Icons.chevron_right, size: 18),
                  label: const Text('Suivant'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _RegistreRow extends ConsumerWidget {
  final TransactionRegistreItem item;
  final String devise;

  const _RegistreRow({required this.item, required this.devise});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRetrait = item.type == TypeTransaction.retrait;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: (isRetrait ? Colors.amber : Colors.green).withValues(alpha: 0.15),
        child: Icon(
          isRetrait ? Icons.arrow_upward : Icons.arrow_downward,
          color: isRetrait ? Colors.amber.shade800 : Colors.green.shade800,
          size: 18,
        ),
      ),
      title: Text('${item.clientNom} · ${item.compteNumero}'),
      subtitle: Text(
        '${_montantFormat.format(item.montant)} $devise · '
        '${item.collecteParNom} · '
        '${_dateTimeFormat.format(item.date)}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Chip(
            label: Text(typeTransactionLabel(item.type)),
            backgroundColor: (isRetrait ? Colors.amber : Colors.green).withValues(alpha: 0.12),
            labelStyle: TextStyle(
              color: isRetrait ? Colors.amber.shade800 : Colors.green.shade800,
              fontWeight: FontWeight.w600,
            ),
            side: BorderSide.none,
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined, size: 20),
            tooltip: 'Imprimer le reçu',
            onPressed: () => imprimerRecu(
              context,
              ref,
              transaction: item,
              compteNumero: item.compteNumero,
              clientNom: item.clientNom,
            ),
          ),
        ],
      ),
    );
  }
}
