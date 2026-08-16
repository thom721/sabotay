import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../features/comptes/domain/compte_sabotay.dart';
import '../../features/entreprise/domain/entreprise_profil.dart';
import '../../features/transactions/domain/transaction.dart';
import 'printer_settings.dart';

// Les imprimantes ESC/POS ne supportent que le Latin-1 (ISO-8859-1) — au-delà,
// chaque caractère devient un octet 0x3F ('?'). NumberFormat('fr') utilise une
// espace fine insécable (U+202F) comme séparateur de milliers, ce qui produit
// un "?" entre les chiffres (ex: "1?250,00" au lieu de "1 250,00") — normalisée
// ici en espace ASCII avant l'encodage (même correctif que pos_api).
int _escposByte(int codeUnit) {
  const nonBreakingSpaces = {0x00A0, 0x2007, 0x2009, 0x200A, 0x202F};
  if (nonBreakingSpaces.contains(codeUnit)) return 0x20;
  return codeUnit <= 0xFF ? codeUnit : 0x3F;
}

/// Impression ESC/POS directe sur une imprimante thermique Bluetooth
/// appairée — même mécanisme que pos_api (`print_bluetooth_thermal` +
/// canal natif Android pour la connexion RFCOMM, voir MainActivity.kt) :
/// le plugin seul ne gère pas la connexion sur toutes les imprimantes
/// génériques, d'où le canal `sabotaypro/bluetooth` fait main.
class BluetoothPrintService {
  BluetoothPrintService._();
  static final BluetoothPrintService instance = BluetoothPrintService._();

  static const _ch = MethodChannel('sabotaypro/bluetooth');

  Future<List<BluetoothInfo>> getPairedPrinters() async {
    if (kIsWeb) return [];
    try {
      // Sur Android 12+, BLUETOOTH_CONNECT est une permission runtime. Si
      // elle n'est pas accordée, le plugin retourne sans résoudre le Future
      // → spinner infini. On vérifie d'abord, puis on ajoute un timeout de
      // sécurité pour ne jamais bloquer l'UI.
      final granted = await PrintBluetoothThermal.isPermissionBluetoothGranted;
      if (!granted) return [];
      return await PrintBluetoothThermal.pairedBluetooths
          .timeout(const Duration(seconds: 6), onTimeout: () => []);
    } catch (_) {
      return [];
    }
  }

  Future<bool> connect(String mac) async {
    if (mac.isEmpty) return false;
    try {
      await _ch.invokeMethod('disconnect');
    } catch (_) {}

    // Connexion RFCOMM non-sécurisée via Method Channel Android — quelques
    // tentatives, certaines imprimantes bon marché refusent la première
    // connexion après une mise en veille Bluetooth.
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final ok = await _ch
            .invokeMethod<bool>('connect', {'mac': mac})
            .timeout(const Duration(seconds: 10), onTimeout: () => false);
        if (ok == true) return true;
      } catch (_) {}
      if (attempt < 2) await Future.delayed(const Duration(milliseconds: 800));
    }
    return false;
  }

  Future<void> disconnect() async {
    try {
      await _ch.invokeMethod('disconnect');
    } catch (_) {}
  }

  Future<bool> _sendBytes(List<int> bytes) async {
    try {
      final ok = await _ch.invokeMethod<bool>('sendBytes', {'bytes': Uint8List.fromList(bytes)});
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  /// Imprime le reçu de collecte/retrait sur l'imprimante Bluetooth
  /// configurée (ou [mac] explicite). Retourne `false` sans lever
  /// d'exception si aucune imprimante n'est configurée/joignable — l'appelant
  /// (`ThermalPrinterService`) bascule alors sur le repli PDF.
  Future<bool> printRecu({
    required Transaction transaction,
    required CompteSabotay compte,
    required String clientNom,
    required EntrepriseProfil entreprise,
    required PrinterSettings printerSettings,
    String? mac,
  }) async {
    final printerMac = mac ?? printerSettings.bluetoothPrinterMac;
    if (printerMac.isEmpty) return false;

    final connected = await connect(printerMac);
    if (!connected) return false;

    final bytes = _buildEscPos(transaction, compte, clientNom, entreprise, printerSettings);
    return _sendBytes(bytes);
  }

  // ── Constructeur ESC/POS ────────────────────────────────────────────────

  Uint8List _buildEscPos(
    Transaction transaction,
    CompteSabotay compte,
    String clientNom,
    EntrepriseProfil entreprise,
    PrinterSettings printerSettings,
  ) {
    final buf = <int>[];
    final numFmt = NumberFormat('#,##0.00', 'fr');
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');
    final largeurMm = printerSettings.paperWidthMm ??
        int.tryParse(entreprise.formatRecu.replaceAll(RegExp('[^0-9]'), '')) ??
        80;

    // Nombre de caractères par ligne : ~48 sur un rouleau 80mm, ~32 en
    // dessous (58/48mm) — même simplification que pos_api, la police ESC/POS
    // standard ne varie pas assez entre 58 et 48mm pour justifier une
    // troisième valeur.
    final cols = largeurMm >= 80 ? 48 : 32;
    final labelW = cols - 16;

    void esc(List<int> cmd) => buf.addAll(cmd);
    // WPC1252 : les caractères français (U+00C0–U+00FF) ont le même octet que
    // leur code point Unicode. Les chars hors Latin-1 sont remplacés par '?'.
    void text(String t) => buf.addAll(t.codeUnits.map(_escposByte));
    void nl([int n = 1]) {
      for (var i = 0; i < n; i++) {
        buf.add(10);
      }
    }

    void dash() {
      text('-' * cols);
      nl();
    }

    void row(String label, String value, {bool isBold = false}) {
      if (isBold) esc([0x1B, 0x45, 0x01]);
      text(label.padRight(labelW) + value.padLeft(16));
      nl();
      if (isBold) esc([0x1B, 0x45, 0x00]);
    }

    String montant(num v) => '${numFmt.format(v)} ${entreprise.devise}';

    // Init + code page WPC1252 + assombrissement maximum (mêmes réglages que
    // le reçu de vente pos_api — sans ça, certaines imprimantes bon marché
    // impriment trop pâle même à pleine intensité logicielle).
    esc([0x1B, 0x40]); // Initialize printer
    esc([0x1B, 0x37, 0x07, 0x96, 0x02]); // ESC 7: heating max
    esc([0x1B, 0x74, 0x10]); // Code page 16 = WPC1252
    esc([0x1B, 0x47, 0x01]); // Double-strike ON
    esc([0x1B, 0x45, 0x01]); // Bold ON global

    // ── En-tête ──────────────────────────────────────────────────────────
    esc([0x1B, 0x61, 0x01]);
    esc([0x1D, 0x21, 0x10]); // double hauteur
    text(entreprise.nom);
    nl();
    esc([0x1D, 0x21, 0x00]);
    if ((entreprise.adresse ?? '').isNotEmpty) {
      text(entreprise.adresse!);
      nl();
    }
    if ((entreprise.telephoneContact ?? '').isNotEmpty) {
      text(entreprise.telephoneContact!);
      nl();
    }
    esc([0x1B, 0x61, 0x00]);
    nl();
    dash();

    // ── Titre ────────────────────────────────────────────────────────────
    final isRetrait = transaction.type == TypeTransaction.retrait;
    esc([0x1B, 0x61, 0x01]);
    esc([0x1B, 0x45, 0x01]);
    text(isRetrait ? 'REÇU DE RETRAIT' : 'REÇU DE COLLECTE');
    nl();
    esc([0x1B, 0x45, 0x00]);
    esc([0x1B, 0x61, 0x00]);
    dash();
    nl();

    // ── Détail ───────────────────────────────────────────────────────────
    row('Client', clientNom);
    row('N° de compte', compte.numeroCompte);
    row('Date', dateFmt.format(transaction.date));
    nl();
    if (isRetrait) {
      final frais = transaction.frais ?? 0;
      final montantNet = transaction.montant - frais;
      row('Montant demandé', montant(transaction.montant));
      row('Frais', montant(frais));
      row('Montant net remis', montant(montantNet), isBold: true);
    } else {
      row('Jours payés', '${transaction.nbJours ?? 1}');
      row('Montant', montant(transaction.montant), isBold: true);
    }
    nl();
    row(isRetrait ? 'Traité par' : 'Collecté par', transaction.collecteParNom);
    row('Reçu N°', transaction.numero);
    dash();

    if ((entreprise.texteBasRecu ?? '').isNotEmpty) {
      nl();
      esc([0x1B, 0x61, 0x01]);
      text(entreprise.texteBasRecu!);
      nl();
      esc([0x1B, 0x61, 0x00]);
    }

    nl(4);
    esc([0x1D, 0x56, 0x42, 0x00]); // coupe partielle

    return Uint8List.fromList(buf);
  }
}
