import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../../core/printing/bluetooth_print_service.dart';
import '../../../core/printing/printer_settings.dart';
import '../../../core/printing/thermal_printer_service.dart';

/// Réglages d'impression — locaux à l'appareil (voir `PrinterSettings`).
/// Affiche le mode détecté (Sunmi / Bluetooth / PDF système), permet de
/// choisir une largeur de papier propre à cet appareil et d'appairer une
/// imprimante Bluetooth ESC/POS pour les reçus de collecte/retrait.
Future<void> showImprimanteSettingsSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _ImprimanteSettingsSheet(),
  );
}

class _ImprimanteSettingsSheet extends ConsumerStatefulWidget {
  const _ImprimanteSettingsSheet();

  @override
  ConsumerState<_ImprimanteSettingsSheet> createState() => _ImprimanteSettingsSheetState();
}

class _ImprimanteSettingsSheetState extends ConsumerState<_ImprimanteSettingsSheet> {
  bool _recherche = false;
  List<BluetoothInfo> _imprimantesTrouvees = [];

  Future<void> _rechercherImprimantes() async {
    setState(() => _recherche = true);
    final imprimantes = await BluetoothPrintService.instance.getPairedPrinters();
    if (!mounted) return;
    setState(() {
      _imprimantesTrouvees = imprimantes;
      _recherche = false;
    });
    if (imprimantes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Aucune imprimante Bluetooth appairée trouvée. Appairez-la d\'abord '
            'dans les réglages Bluetooth du téléphone.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final printerSettingsAsync = ref.watch(printerSettingsProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Imprimante', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            _ModeDetecteRow(printerSettings: printerSettingsAsync.valueOrNull),
            const SizedBox(height: 24),
            printerSettingsAsync.when(
              data: (printerSettings) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionFormatPapier(printerSettings: printerSettings),
                  const SizedBox(height: 24),
                  _SectionBluetooth(
                    printerSettings: printerSettings,
                    recherche: _recherche,
                    imprimantesTrouvees: _imprimantesTrouvees,
                    onRechercher: _rechercherImprimantes,
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Impossible de charger les réglages'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeDetecteRow extends StatelessWidget {
  final PrinterSettings? printerSettings;

  const _ModeDetecteRow({required this.printerSettings});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: ThermalPrinterService.instance.isSunmiAvailable,
      builder: (context, snapshot) {
        final String mode;
        final IconData icon;
        if (snapshot.data == true) {
          mode = 'Terminal Sunmi détecté — impression directe';
          icon = Icons.point_of_sale;
        } else if (printerSettings?.aUneImprimanteBluetooth ?? false) {
          mode = 'Imprimante Bluetooth configurée : ${printerSettings!.bluetoothPrinterName}';
          icon = Icons.bluetooth_connected;
        } else {
          mode = 'Aucune imprimante configurée — partage/impression système par défaut';
          icon = Icons.picture_as_pdf_outlined;
        }
        return Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(mode, style: Theme.of(context).textTheme.bodyMedium)),
          ],
        );
      },
    );
  }
}

class _SectionFormatPapier extends ConsumerWidget {
  final PrinterSettings printerSettings;

  const _SectionFormatPapier({required this.printerSettings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Format papier (cet appareil)', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          'Par défaut, suit le réglage de l\'entreprise. À ajuster ici seulement '
          'si l\'imprimante de cet appareil utilise un rouleau différent.',
          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _ChoixLargeur(label: 'Auto', valeur: null, actuel: printerSettings.paperWidthMm),
            _ChoixLargeur(label: '48 mm', valeur: 48, actuel: printerSettings.paperWidthMm),
            _ChoixLargeur(label: '58 mm', valeur: 58, actuel: printerSettings.paperWidthMm),
            _ChoixLargeur(label: '80 mm', valeur: 80, actuel: printerSettings.paperWidthMm),
          ],
        ),
      ],
    );
  }
}

class _ChoixLargeur extends ConsumerWidget {
  final String label;
  final int? valeur;
  final int? actuel;

  const _ChoixLargeur({required this.label, required this.valeur, required this.actuel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectionne = valeur == actuel;
    return ChoiceChip(
      label: Text(label),
      selected: selectionne,
      onSelected: (_) => ref.read(printerSettingsProvider.notifier).setPaperWidthMm(valeur),
    );
  }
}

class _SectionBluetooth extends ConsumerWidget {
  final PrinterSettings printerSettings;
  final bool recherche;
  final List<BluetoothInfo> imprimantesTrouvees;
  final VoidCallback onRechercher;

  const _SectionBluetooth({
    required this.printerSettings,
    required this.recherche,
    required this.imprimantesTrouvees,
    required this.onRechercher,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Imprimante Bluetooth', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          'Appairez d\'abord l\'imprimante dans les réglages Bluetooth du '
          'téléphone, puis sélectionnez-la ici.',
          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        if (printerSettings.aUneImprimanteBluetooth)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.bluetooth_connected),
            title: Text(printerSettings.bluetoothPrinterName),
            subtitle: Text(printerSettings.bluetoothPrinterMac),
            trailing: TextButton(
              onPressed: () => ref.read(printerSettingsProvider.notifier).clearBluetoothPrinter(),
              child: const Text('Retirer'),
            ),
          ),
        OutlinedButton.icon(
          onPressed: recherche ? null : onRechercher,
          icon: recherche
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.bluetooth_searching),
          label: const Text('Rechercher les imprimantes appairées'),
        ),
        for (final imprimante in imprimantesTrouvees)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.print_outlined),
            title: Text(imprimante.name),
            subtitle: Text(imprimante.macAdress),
            onTap: () => ref.read(printerSettingsProvider.notifier).setBluetoothPrinter(
                  mac: imprimante.macAdress,
                  nom: imprimante.name,
                ),
          ),
      ],
    );
  }
}
