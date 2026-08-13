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

final _dateFormatLong = DateFormat('d MMMM yyyy', 'fr');
final _amountFormat = NumberFormat.decimalPattern('fr');

const _grisTexte = PdfColor.fromInt(0xFF666666);
const _grisLigne = PdfColor.fromInt(0xFFDDDDDD);

/// Génère le PDF du reçu de paiement d'abonnement — format facture pleine
/// page (A4), pas le format thermique des reçus de collecte/retrait (ceux-là
/// restent sur `transactions/presentation/recu_pdf.dart`) : un abonnement
/// annuel B2B se documente comme une facture, pas comme un ticket de caisse.
Future<Uint8List> _buildRecuAbonnementPdf({
  required PaiementAbonnement paiement,
  required EntrepriseProfile entreprise,
}) {
  final numeroRecu = 'AB-${paiement.id.substring(0, 8).toUpperCase()}';
  final methodeLabel = paiement.methode == 'especes' ? 'Espèces' : 'MonCash';

  final document = pw.Document();
  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Reçu', style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold)),
              pw.Text(
                'SabotayPro',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Row(
            children: [
              _champ('Numéro de reçu', numeroRecu),
              pw.SizedBox(width: 40),
              _champ('Date payée', _dateFormatLong.format(paiement.datePaiement)),
              pw.SizedBox(width: 40),
              _champ('Méthode', methodeLabel),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('SabotayPro',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text('sabotay.infini-software.cloud',
                        style: const pw.TextStyle(fontSize: 9, color: _grisTexte)),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Facturé à',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text(entreprise.nom, style: const pw.TextStyle(fontSize: 9)),
                    if (entreprise.adresse != null && entreprise.adresse!.isNotEmpty)
                      pw.Text(entreprise.adresse!,
                          style: const pw.TextStyle(fontSize: 9, color: _grisTexte)),
                    if (entreprise.telephoneContact != null &&
                        entreprise.telephoneContact!.isNotEmpty)
                      pw.Text(entreprise.telephoneContact!,
                          style: const pw.TextStyle(fontSize: 9, color: _grisTexte)),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 32),
          pw.Text(
            '${_amountFormat.format(paiement.montant)} ${entreprise.devise} payé le '
            '${_dateFormatLong.format(paiement.datePaiement)}',
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 16),
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: _grisLigne)),
            ),
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Description',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.Text('Montant',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Abonnement annuel SabotayPro', style: const pw.TextStyle(fontSize: 10)),
                pw.Text(
                  '${_amountFormat.format(paiement.montant)} ${entreprise.devise}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: _grisLigne)),
            ),
            padding: const pw.EdgeInsets.only(top: 8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _totalLigne('Sous-total', '${_amountFormat.format(paiement.montant)} ${entreprise.devise}'),
                _totalLigne('Total', '${_amountFormat.format(paiement.montant)} ${entreprise.devise}'),
                _totalLigne(
                  'Montant payé',
                  '${_amountFormat.format(paiement.montant)} ${entreprise.devise}',
                  gras: true,
                ),
              ],
            ),
          ),
          if (paiement.moncashOrderId != null) ...[
            pw.SizedBox(height: 16),
            pw.Text('Référence MonCash : ${paiement.moncashOrderId}',
                style: const pw.TextStyle(fontSize: 9, color: _grisTexte)),
          ],
          if (paiement.payeParNom != null) ...[
            pw.SizedBox(height: 4),
            pw.Text('Confirmé par ${paiement.payeParNom}',
                style: const pw.TextStyle(fontSize: 9, color: _grisTexte)),
          ],
        ],
      ),
    ),
  );
  return document.save();
}

pw.Widget _champ(String label, String valeur) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        pw.Text(valeur, style: const pw.TextStyle(fontSize: 9)),
      ],
    );

pw.Widget _totalLigne(String label, String valeur, {bool gras = false}) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(
              label,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: gras ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
          pw.SizedBox(width: 16),
          pw.Text(
            valeur,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: gras ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
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
