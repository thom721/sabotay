import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';

import '../../features/comptes/domain/compte_sabotay.dart';
import '../../features/entreprise/domain/entreprise_profil.dart';
import '../../features/transactions/domain/transaction.dart';
import 'bluetooth_print_service.dart';
import 'printer_settings.dart';

/// Abstraction d'impression thermique pour les reçus de paiement
/// (collecte/retrait) — même architecture que pos_api
/// (`thermal_printer_service.dart`) : sur un terminal Sunmi, SDK intégré,
/// impression instantanée sans PDF ; sinon une imprimante Bluetooth ESC/POS
/// appairée si configurée ; sinon repli PDF via le sélecteur système/partage.
class ThermalPrinterService {
  ThermalPrinterService._();
  static final ThermalPrinterService instance = ThermalPrinterService._();

  // null = pas encore sondé, true/false = résultat mis en cache.
  bool? _isSunmi;

  Future<bool> _checkSunmi() async {
    if (kIsWeb) return false;
    _isSunmi ??= await _probeSunmi();
    return _isSunmi!;
  }

  Future<bool> _probeSunmi() async {
    try {
      // getStatus() renvoie non-null sur un vrai terminal Sunmi ; lève une
      // PlatformException ou renvoie null sur tout autre appareil Android.
      final status = await SunmiConfig.getStatus();
      return status != null;
    } catch (_) {
      return false;
    }
  }

  Future<bool> get isSunmiAvailable => _checkSunmi();

  /// Imprime le reçu — choisit automatiquement Sunmi, Bluetooth ou PDF selon
  /// ce qui est disponible/configuré sur l'appareil. [buildPdfBytes] fournit
  /// le PDF de repli (voir `recu_pdf.dart`), pour ne pas dupliquer le layout
  /// PDF ici.
  Future<void> printRecu({
    required Transaction transaction,
    required CompteSabotay compte,
    required String clientNom,
    required EntrepriseProfil entreprise,
    required PrinterSettings printerSettings,
    required Future<Uint8List> Function() buildPdfBytes,
  }) async {
    if (await _checkSunmi()) {
      await _printSunmi(transaction, compte, clientNom, entreprise);
      return;
    }

    if (printerSettings.aUneImprimanteBluetooth) {
      final ok = await BluetoothPrintService.instance.printRecu(
        transaction: transaction,
        compte: compte,
        clientNom: clientNom,
        entreprise: entreprise,
        printerSettings: printerSettings,
      );
      if (ok) return;
      // L'imprimante configurée n'a pas répondu (éteinte, hors de portée…) —
      // on bascule sur le PDF plutôt que de laisser l'agent sans reçu.
    }

    final bytes = await buildPdfBytes();
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: 'Recu-${transaction.numero}');
  }

  // ── Impression Sunmi ─────────────────────────────────────────────────────

  Future<void> _printSunmi(
    Transaction transaction,
    CompteSabotay compte,
    String clientNom,
    EntrepriseProfil entreprise,
  ) async {
    final numFmt = NumberFormat('#,##0.00', 'fr');
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');
    final isRetrait = transaction.type == TypeTransaction.retrait;
    String montant(num v) => '${numFmt.format(v)} ${entreprise.devise}';

    await SunmiPrinter.printText(
      '${entreprise.nom}\n',
      style: SunmiTextStyle(fontSize: 36, align: SunmiPrintAlign.CENTER, bold: true),
    );
    if ((entreprise.adresse ?? '').isNotEmpty) {
      await SunmiPrinter.printText(
        '${entreprise.adresse}\n',
        style: SunmiTextStyle(fontSize: 24, align: SunmiPrintAlign.CENTER),
      );
    }
    if ((entreprise.telephoneContact ?? '').isNotEmpty) {
      await SunmiPrinter.printText(
        '${entreprise.telephoneContact}\n',
        style: SunmiTextStyle(fontSize: 24, align: SunmiPrintAlign.CENTER),
      );
    }
    await SunmiPrinter.line();
    await SunmiPrinter.lineWrap(1);

    await SunmiPrinter.printText(
      '${isRetrait ? 'REÇU DE RETRAIT' : 'REÇU DE COLLECTE'}\n',
      style: SunmiTextStyle(fontSize: 28, bold: true, align: SunmiPrintAlign.CENTER),
    );
    await SunmiPrinter.line();
    await SunmiPrinter.lineWrap(1);

    Future<void> ligne(String label, String valeur, {bool bold = false}) => SunmiPrinter.printRow(
          cols: [
            SunmiColumn(
              text: label,
              width: 20,
              style: SunmiTextStyle(bold: bold, align: SunmiPrintAlign.LEFT),
            ),
            SunmiColumn(
              text: valeur,
              width: 12,
              style: SunmiTextStyle(bold: bold, align: SunmiPrintAlign.RIGHT),
            ),
          ],
        );

    await ligne('Client', clientNom);
    await ligne('N° de compte', compte.numeroCompte);
    await ligne('Date', dateFmt.format(transaction.date));
    await SunmiPrinter.lineWrap(1);

    if (isRetrait) {
      final frais = transaction.frais ?? 0;
      final montantNet = transaction.montant - frais;
      await ligne('Montant demandé', montant(transaction.montant));
      await ligne('Frais', montant(frais));
      await ligne('Montant net remis', montant(montantNet), bold: true);
    } else {
      await ligne('Jours payés', '${transaction.nbJours ?? 1}');
      await ligne('Montant', montant(transaction.montant), bold: true);
    }
    await SunmiPrinter.lineWrap(1);
    await ligne(isRetrait ? 'Traité par' : 'Collecté par', transaction.collecteParNom);
    await ligne('Reçu N°', transaction.numero);
    await SunmiPrinter.line();

    if ((entreprise.texteBasRecu ?? '').isNotEmpty) {
      await SunmiPrinter.lineWrap(1);
      await SunmiPrinter.printText(
        '${entreprise.texteBasRecu}\n',
        style: SunmiTextStyle(fontSize: 24, align: SunmiPrintAlign.CENTER),
      );
    }

    await SunmiPrinter.lineWrap(3);
    try {
      await SunmiPrinter.cutPaper();
    } catch (_) {
      // Modèles handheld sans coupe-papier (ex. H10).
    }
  }
}
