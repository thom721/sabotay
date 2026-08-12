import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../entreprise/presentation/entreprise_providers.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../transactions/domain/transaction.dart';

final _dateFormat = DateFormat('dd/MM/yyyy');
final _amountFormat = NumberFormat.decimalPattern('fr');

/// Rapport de collecte imprimable sur une période (PRD §8.7 : "résumé
/// journalier/mensuel", "export CSV/PDF des rapports de base"). Un Agent ne
/// voit que ses propres collectes, Admin/Manager voient tout le tenant —
/// filtrage déjà appliqué côté backend (GET /transactions/rapport).
class RapportScreen extends ConsumerStatefulWidget {
  const RapportScreen({super.key});

  @override
  ConsumerState<RapportScreen> createState() => _RapportScreenState();
}

class _RapportScreenState extends ConsumerState<RapportScreen> {
  DateTimeRange _periode = DateTimeRange(start: DateTime.now(), end: DateTime.now());
  Rapport? _rapport;
  bool _isLoading = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _isLoading = true;
      _erreur = null;
    });
    try {
      final rapport = await ref.read(transactionRepositoryProvider).getRapport(
            dateDebut: _periode.start,
            dateFin: _periode.end,
          );
      setState(() {
        _rapport = rapport;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _erreur = 'Impossible de charger le rapport';
        _isLoading = false;
      });
    }
  }

  Future<void> _choisirPeriode() async {
    final choisie = await showDateRangePicker(
      context: context,
      initialDateRange: _periode,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (choisie != null) {
      setState(() => _periode = choisie);
      await _charger();
    }
  }

  Future<void> _imprimer() async {
    final rapport = _rapport;
    if (rapport == null) return;
    try {
      final entreprise = await ref.read(entrepriseProfilProvider.future);
      final pdfBytes = await _buildRapportPdf(rapport: rapport, entrepriseNom: entreprise.nom);
      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: 'Rapport-${_dateFormat.format(rapport.dateDebut)}',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de générer le rapport')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rapport = _rapport;
    return Scaffold(
      appBar: AppBar(title: const Text('Rapport de collecte')),
      floatingActionButton: rapport == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _imprimer,
              icon: const Icon(Icons.print_outlined),
              label: const Text('Imprimer'),
            ),
      body: RefreshIndicator(
        onRefresh: _charger,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.date_range),
                title: Text(
                  '${_dateFormat.format(_periode.start)} → ${_dateFormat.format(_periode.end)}',
                ),
                trailing: TextButton(
                  onPressed: _choisirPeriode,
                  child: const Text('Modifier'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading) const Center(child: CircularProgressIndicator()),
            if (_erreur != null) Center(child: Text(_erreur!)),
            if (rapport != null) ...[
              _TotauxCard(rapport: rapport),
              const SizedBox(height: 16),
              if (rapport.transactions.isEmpty)
                const Center(child: Text('Aucune transaction sur cette période'))
              else
                for (final transaction in rapport.transactions) _RapportTile(transaction: transaction),
              const SizedBox(height: 80),
            ],
          ],
        ),
      ),
    );
  }
}

class _TotauxCard extends StatelessWidget {
  final Rapport rapport;

  const _TotauxCard({required this.rapport});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${rapport.nbTransactions} transaction(s)', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Total collecté : ${_amountFormat.format(rapport.totalCollecte)} HTG'),
            if (rapport.totalRetrait > 0)
              Text('Total retiré : ${_amountFormat.format(rapport.totalRetrait)} HTG'),
          ],
        ),
      ),
    );
  }
}

class _RapportTile extends StatelessWidget {
  final Transaction transaction;

  const _RapportTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isRetrait = transaction.type == TypeTransaction.retrait;
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      leading: Icon(
        isRetrait ? Icons.arrow_upward : Icons.check_circle_outline,
        color: isRetrait ? colorScheme.tertiary : colorScheme.secondary,
      ),
      title: Text('${_amountFormat.format(transaction.montant)} HTG'),
      subtitle: Text('${_dateFormat.format(transaction.date)} • ${transaction.collecteParNom}'),
      trailing: Text(typeTransactionLabel(transaction.type)),
    );
  }
}

Future<Uint8List> _buildRapportPdf({required Rapport rapport, required String entrepriseNom}) {
  final document = pw.Document();
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Text(entrepriseNom, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.Text('Rapport de collecte', style: const pw.TextStyle(fontSize: 12)),
        pw.Text(
          'Période : ${_dateFormat.format(rapport.dateDebut)} → ${_dateFormat.format(rapport.dateFin)}',
        ),
        pw.SizedBox(height: 12),
        pw.Text('Total collecté : ${_amountFormat.format(rapport.totalCollecte)} HTG'),
        if (rapport.totalRetrait > 0)
          pw.Text('Total retiré : ${_amountFormat.format(rapport.totalRetrait)} HTG'),
        pw.Text('${rapport.nbTransactions} transaction(s)'),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headers: ['Date', 'Compte', 'Montant', 'Type', 'Collecté par'],
          data: [
            for (final transaction in rapport.transactions)
              [
                _dateFormat.format(transaction.date),
                '#${transaction.compteId}',
                '${_amountFormat.format(transaction.montant)} HTG',
                typeTransactionLabel(transaction.type),
                transaction.collecteParNom,
              ],
          ],
        ),
      ],
    ),
  );
  return document.save();
}
