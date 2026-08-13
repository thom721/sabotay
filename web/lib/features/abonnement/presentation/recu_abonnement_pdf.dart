import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../entreprise/data/entreprise_repository.dart';
import '../../entreprise/domain/entreprise_profile.dart';
import '../domain/paiement_abonnement.dart';

final _dateFormat = DateFormat('dd/MM/yyyy');
final _amountFormat = NumberFormat.decimalPattern('fr');

/// Génère le PDF du reçu de paiement d'abonnement — même format papier que
/// les reçus de collecte/retrait (`transactions/presentation/recu_pdf.dart`),
/// pour rester imprimable sur la même imprimante thermique.
Future<Uint8List> _buildRecuAbonnementPdf({
  required PaiementAbonnement paiement,
  required EntrepriseProfile entreprise,
}) {
  final largeurMm = double.tryParse(
        entreprise.formatRecu.replaceAll(RegExp('[^0-9.]'), ''),
      ) ??
      80;
  final format = PdfPageFormat(
    largeurMm * PdfPageFormat.mm,
    double.infinity,
    marginAll: 5 * PdfPageFormat.mm,
  );

  final document = pw.Document();
  document.addPage(
    pw.Page(
      pageFormat: format,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Center(
            child: pw.Text(
              entreprise.nom,
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
          ),
          if (entreprise.adresse != null && entreprise.adresse!.isNotEmpty)
            pw.Center(child: pw.Text(entreprise.adresse!, style: const pw.TextStyle(fontSize: 8))),
          if (entreprise.telephoneContact != null && entreprise.telephoneContact!.isNotEmpty)
            pw.Center(
              child: pw.Text(entreprise.telephoneContact!, style: const pw.TextStyle(fontSize: 8)),
            ),
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Text(
              'REÇU DE PAIEMENT — ABONNEMENT',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Divider(),
          _ligne('Date', _dateFormat.format(paiement.datePaiement)),
          _ligne('Montant', '${_amountFormat.format(paiement.montant)} ${entreprise.devise}'),
          if (paiement.moncashOrderId != null)
            _ligne('Référence MonCash', paiement.moncashOrderId!),
          if (paiement.payeParNom != null) _ligne('Confirmé par', paiement.payeParNom!),
          _ligne('Reçu N°', 'AB-${paiement.id}'),
          pw.Divider(),
          if (entreprise.texteBasRecu != null && entreprise.texteBasRecu!.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text(entreprise.texteBasRecu!, style: const pw.TextStyle(fontSize: 8)),
            ),
          ],
        ],
      ),
    ),
  );
  return document.save();
}

pw.Widget _ligne(String label, String valeur) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
          pw.Text(valeur, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );

/// Ouvre l'aperçu d'impression/partage du reçu de paiement d'abonnement.
///
/// [entreprise] est optionnel : par défaut, récupéré via
/// `entrepriseProfileProvider` (`GET /entreprises/profil`). Le super-admin
/// n'a pas ce token (voir `superadmin_entreprise_detail_screen.dart`), donc
/// il doit toujours passer le profil résolu depuis
/// `EntrepriseSuperAdminRead`.
Future<void> imprimerRecuAbonnement(
  BuildContext context,
  WidgetRef ref, {
  required PaiementAbonnement paiement,
  EntrepriseProfile? entreprise,
}) async {
  try {
    final EntrepriseProfile entrepriseResolue;
    if (entreprise != null) {
      entrepriseResolue = entreprise;
    } else {
      entrepriseResolue = await ref.read(entrepriseProfileProvider.future);
    }
    final pdfBytes = await _buildRecuAbonnementPdf(
      paiement: paiement,
      entreprise: entrepriseResolue,
    );
    await Printing.layoutPdf(
      onLayout: (_) async => pdfBytes,
      name: 'Recu-AB-${paiement.id}',
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de générer le reçu')),
      );
    }
  }
}
