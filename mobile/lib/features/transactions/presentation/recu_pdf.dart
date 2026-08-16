import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/printing/printer_settings.dart';
import '../../../core/printing/thermal_printer_service.dart';
import '../../comptes/domain/compte_sabotay.dart';
import '../../entreprise/domain/entreprise_profil.dart';
import '../../entreprise/presentation/entreprise_providers.dart';
import '../domain/transaction.dart';

final _dateFormat = DateFormat('dd/MM/yyyy');
final _amountFormat = NumberFormat.decimalPattern('fr');

/// Génère le PDF du reçu — largeur papier prise sur [largeurMmOverride]
/// (réglage local à l'appareil, voir `PrinterSettings`) si fourni, sinon sur
/// le format de l'entreprise (`entreprise.formatRecu`, "58mm"/"80mm" — cf.
/// `Entreprise.format_recu` côté backend). Bifurque sur le type : une
/// collecte affiche le nombre de jours payés, un retrait affiche les frais
/// et le montant net remis.
Future<Uint8List> buildRecuPdf({
  required Transaction transaction,
  required CompteSabotay compte,
  required String clientNom,
  required EntrepriseProfil entreprise,
  int? largeurMmOverride,
}) {
  final largeurMm = largeurMmOverride?.toDouble() ??
      double.tryParse(
        entreprise.formatRecu.replaceAll(RegExp('[^0-9.]'), ''),
      ) ??
      80;
  final format = PdfPageFormat(
    largeurMm * PdfPageFormat.mm,
    double.infinity,
    marginAll: 5 * PdfPageFormat.mm,
  );

  final isRetrait = transaction.type == TypeTransaction.retrait;
  final frais = transaction.frais ?? 0;
  final montantNet = transaction.montant - frais;

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
              isRetrait ? 'REÇU DE RETRAIT' : 'REÇU DE COLLECTE',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Divider(),
          _ligne('Client', clientNom),
          _ligne('N° de compte', compte.numeroCompte),
          _ligne('Date', _dateFormat.format(transaction.date)),
          if (isRetrait) ...[
            _ligne('Montant demandé', '${_amountFormat.format(transaction.montant)} ${entreprise.devise}'),
            _ligne('Frais', '${_amountFormat.format(frais)} ${entreprise.devise}'),
            _ligne('Montant net remis', '${_amountFormat.format(montantNet)} ${entreprise.devise}'),
          ] else ...[
            _ligne('Jours payés', '${transaction.nbJours ?? 1}'),
            _ligne('Montant', '${_amountFormat.format(transaction.montant)} ${entreprise.devise}'),
          ],
          _ligne(isRetrait ? 'Traité par' : 'Collecté par', transaction.collecteParNom),
          _ligne('Reçu N°', transaction.numero),
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

/// Ouvre l'aperçu d'impression/partage du reçu — collecte ou retrait, les
/// deux sont désormais toujours des événements réels (plus de statut
/// "manqué" stocké), donc toujours imprimables.
///
/// [entreprise] est optionnel : par défaut, récupéré via
/// `entrepriseProfilProvider` (`GET /entreprises/profil`, accessible aux
/// tokens Utilisateur). Le portail Client n'a pas accès à cette route
/// (`TenantId` rejette les tokens Client) — il doit donc passer son propre
/// profil entreprise déjà récupéré via `GET /clients/moi/entreprise`.
Future<void> imprimerRecu(
  BuildContext context,
  WidgetRef ref, {
  required Transaction transaction,
  required CompteSabotay compte,
  required String clientNom,
  EntrepriseProfil? entreprise,
}) async {
  try {
    final EntrepriseProfil entrepriseResolue;
    if (entreprise != null) {
      entrepriseResolue = entreprise;
    } else {
      entrepriseResolue = await ref.read(entrepriseProfilProvider.future);
    }
    final printerSettings = await ref.read(printerSettingsProvider.future);

    await ThermalPrinterService.instance.printRecu(
      transaction: transaction,
      compte: compte,
      clientNom: clientNom,
      entreprise: entrepriseResolue,
      printerSettings: printerSettings,
      buildPdfBytes: () => buildRecuPdf(
        transaction: transaction,
        compte: compte,
        clientNom: clientNom,
        entreprise: entrepriseResolue,
        largeurMmOverride: printerSettings.paperWidthMm,
      ),
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de générer le reçu')),
      );
    }
  }
}
