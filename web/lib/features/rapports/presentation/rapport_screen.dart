import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/async_state_views.dart';
import '../../../core/widgets/dashboard_shell.dart';
import '../../../core/widgets/pos_style_stat_card.dart';
import '../../employees/domain/employee.dart';
import '../../employees/presentation/employee_list_controller.dart';
import '../../entreprise/data/entreprise_repository.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/recu_pdf.dart';

final _dateFormat = DateFormat('dd/MM/yyyy');
final _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
final _montantFormat = NumberFormat.decimalPattern('fr');

/// Rapport de collecte/retrait sur une période, avec filtre optionnel par
/// agent (PRD §8.7 côté web — jusqu'ici seul le mobile agent y avait accès,
/// et sans filtre par agent puisqu'un Agent ne voit que les siennes).
class RapportScreen extends ConsumerStatefulWidget {
  const RapportScreen({super.key});

  @override
  ConsumerState<RapportScreen> createState() => _RapportScreenState();
}

class _RapportScreenState extends ConsumerState<RapportScreen> {
  late DateTime _dateDebut;
  late DateTime _dateFin;
  String? _agentId;
  Future<Rapport>? _rapportFuture;

  @override
  void initState() {
    super.initState();
    final aujourdhui = DateTime.now();
    _dateFin = DateTime(aujourdhui.year, aujourdhui.month, aujourdhui.day);
    _dateDebut = _dateFin.subtract(const Duration(days: 30));
    _charger();
  }

  void _charger() {
    setState(() {
      _rapportFuture = ref.read(transactionRepositoryProvider).getRapport(
            dateDebut: _dateDebut,
            dateFin: _dateFin,
            agentId: _agentId,
          );
    });
  }

  Future<void> _choisirPeriode() async {
    final range = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _dateDebut, end: _dateFin),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (range == null) return;
    setState(() {
      _dateDebut = range.start;
      _dateFin = range.end;
    });
    _charger();
  }

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeeListControllerProvider);

    return DashboardContent(
      title: 'Rapports',
      backgroundColor: const Color(0xFFF0F2F5),
      action: IconButton(
        icon: const Icon(Icons.refresh),
        tooltip: 'Actualiser',
        onPressed: _charger,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: _choisirPeriode,
                icon: const Icon(Icons.date_range, size: 18),
                label: Text(
                  '${_dateFormat.format(_dateDebut)} — ${_dateFormat.format(_dateFin)}',
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String?>(
                  initialValue: _agentId,
                  decoration: const InputDecoration(
                    labelText: 'Agent',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Tous les agents')),
                    ...?employeesAsync.valueOrNull?.map(
                      (e) => DropdownMenuItem<String?>(value: e.id, child: Text(e.nomComplet)),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _agentId = value);
                    _charger();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FutureBuilder<Rapport>(
            future: _rapportFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return ErrorState(
                  message: 'Impossible de charger le rapport',
                  onRetry: _charger,
                );
              }
              final rapport = snapshot.data;
              if (rapport == null) return const SizedBox.shrink();
              return _RapportContent(
                rapport: rapport,
                employees: employeesAsync.valueOrNull ?? const [],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RapportContent extends ConsumerWidget {
  final Rapport rapport;
  final List<Employee> employees;

  const _RapportContent({required this.rapport, required this.employees});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entrepriseAsync = ref.watch(entrepriseProfileProvider);
    final devise = entrepriseAsync.valueOrNull?.devise ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            // Mêmes seuils/ratios que le tableau de bord (AdminDashboardScreen)
            // — sinon les cartes du rapport ont une taille/forme différente de
            // celles du dashboard alors qu'elles utilisent le même widget.
            final columns =
                constraints.maxWidth >= 1100 ? 4 : (constraints.maxWidth >= 480 ? 2 : 1);
            final ratio =
                constraints.maxWidth >= 1100 ? 2.2 : (constraints.maxWidth >= 480 ? 2.0 : 3.2);
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: ratio,
              children: [
                PosStyleStatCard(
                  icon: Icons.payments_outlined,
                  label: 'Total collecté',
                  value: '${_montantFormat.format(rapport.totalCollecte)} $devise',
                  color: const Color(0xFF2CA01C),
                ),
                PosStyleStatCard(
                  icon: Icons.money_off_outlined,
                  label: 'Total retiré',
                  value: '${_montantFormat.format(rapport.totalRetrait)} $devise',
                  color: const Color(0xFFD69E2E),
                ),
                PosStyleStatCard(
                  icon: Icons.receipt_long_outlined,
                  label: 'Transactions',
                  value: rapport.nbTransactions.toString(),
                  color: const Color(0xFF0077C5),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        if (rapport.transactions.isEmpty)
          const EmptyState(message: 'Aucune transaction sur cette période')
        else
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < rapport.transactions.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _TransactionRow(transaction: rapport.transactions[i], devise: devise),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _TransactionRow extends ConsumerWidget {
  final TransactionRegistreItem transaction;
  final String devise;

  const _TransactionRow({required this.transaction, required this.devise});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRetrait = transaction.type == TypeTransaction.retrait;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: (isRetrait ? Colors.amber : Colors.green).withValues(alpha: 0.15),
        child: Icon(
          isRetrait ? Icons.arrow_upward : Icons.arrow_downward,
          color: isRetrait ? Colors.amber.shade800 : Colors.green.shade800,
          size: 18,
        ),
      ),
      title: Text('${transaction.clientNom} · ${transaction.compteNumero}'),
      subtitle: Text(
        '${_montantFormat.format(transaction.montant)} $devise · '
        '${transaction.collecteParNom} · '
        '${_dateTimeFormat.format(transaction.date)}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Chip(
            label: Text(typeTransactionLabel(transaction.type)),
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
              transaction: transaction,
              compteNumero: transaction.compteNumero,
              clientNom: transaction.clientNom,
            ),
          ),
        ],
      ),
    );
  }
}
