import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kKeyPaperWidth = 'printer_paper_width_mm';
const _kKeyBtMac = 'printer_bluetooth_mac';
const _kKeyBtName = 'printer_bluetooth_name';

/// Réglages d'impression thermique — locaux à l'appareil, jamais synchronisés
/// avec le backend : deux téléphones du même agent peuvent être appairés à
/// deux imprimantes Bluetooth différentes (même logique que `device_bt_mac`
/// dans pos_api, `settings_provider.dart`).
class PrinterSettings {
  /// Largeur de papier en mm (48/58/80), ou `null` pour suivre le format de
  /// l'entreprise (`entreprise.formatRecu`, réglage global côté backend).
  final int? paperWidthMm;
  final String bluetoothPrinterMac;
  final String bluetoothPrinterName;

  const PrinterSettings({
    this.paperWidthMm,
    this.bluetoothPrinterMac = '',
    this.bluetoothPrinterName = '',
  });

  bool get aUneImprimanteBluetooth => bluetoothPrinterMac.isNotEmpty;

  PrinterSettings copyWith({
    int? paperWidthMm,
    bool clearPaperWidthMm = false,
    String? bluetoothPrinterMac,
    String? bluetoothPrinterName,
  }) =>
      PrinterSettings(
        paperWidthMm: clearPaperWidthMm ? null : (paperWidthMm ?? this.paperWidthMm),
        bluetoothPrinterMac: bluetoothPrinterMac ?? this.bluetoothPrinterMac,
        bluetoothPrinterName: bluetoothPrinterName ?? this.bluetoothPrinterName,
      );
}

final printerSettingsProvider =
    AsyncNotifierProvider<PrinterSettingsController, PrinterSettings>(
  PrinterSettingsController.new,
);

class PrinterSettingsController extends AsyncNotifier<PrinterSettings> {
  @override
  Future<PrinterSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    return PrinterSettings(
      paperWidthMm: prefs.getInt(_kKeyPaperWidth),
      bluetoothPrinterMac: prefs.getString(_kKeyBtMac) ?? '',
      bluetoothPrinterName: prefs.getString(_kKeyBtName) ?? '',
    );
  }

  Future<void> setPaperWidthMm(int? largeurMm) async {
    final prefs = await SharedPreferences.getInstance();
    if (largeurMm == null) {
      await prefs.remove(_kKeyPaperWidth);
    } else {
      await prefs.setInt(_kKeyPaperWidth, largeurMm);
    }
    state = AsyncData(
      (state.valueOrNull ?? const PrinterSettings())
          .copyWith(paperWidthMm: largeurMm, clearPaperWidthMm: largeurMm == null),
    );
  }

  Future<void> setBluetoothPrinter({required String mac, required String nom}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKeyBtMac, mac);
    await prefs.setString(_kKeyBtName, nom);
    state = AsyncData(
      (state.valueOrNull ?? const PrinterSettings())
          .copyWith(bluetoothPrinterMac: mac, bluetoothPrinterName: nom),
    );
  }

  Future<void> clearBluetoothPrinter() => setBluetoothPrinter(mac: '', nom: '');
}
