import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../clients/data/client_repository.dart';
import '../../clients/domain/client.dart';
import '../../comptes/data/compte_repository.dart';
import '../../comptes/domain/compte_sabotay.dart';
import 'add_collecte_sheet.dart';
import 'retrait_sheet.dart';

/// Collecte rapide (tous rôles) : recherche un compte Sabotay par son
/// numéro (ex. SB-000042) plutôt que de naviguer client par client, puis
/// ouvre le formulaire de collecte habituel une fois le compte identifié.
/// C'est le seul point d'entrée de la collecte (bouton "+" de la page
/// d'accueil), pour éviter toute erreur de sélection de client/compte.
Future<void> showQuickCollecteSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _QuickCollecteSheet(),
  );
}

class _QuickCollecteSheet extends ConsumerStatefulWidget {
  const _QuickCollecteSheet();

  @override
  ConsumerState<_QuickCollecteSheet> createState() => _QuickCollecteSheetState();
}

class _QuickCollecteSheetState extends ConsumerState<_QuickCollecteSheet> {
  final _numeroController = TextEditingController();
  bool _isSearching = false;
  String? _errorMessage;
  CompteSabotay? _compteTrouve;
  Client? _clientTrouve;
  CompteSolde? _soldeTrouve;

  @override
  void dispose() {
    _numeroController.dispose();
    super.dispose();
  }

  Future<void> _rechercher() async {
    final numero = _numeroController.text.trim().toUpperCase();
    if (numero.isEmpty) return;
    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _compteTrouve = null;
      _clientTrouve = null;
      _soldeTrouve = null;
    });
    try {
      final compte = await ref.read(compteRepositoryProvider).getByNumero(numero);
      if (compte == null) {
        setState(() {
          _isSearching = false;
          _errorMessage = 'Aucun compte trouvé pour "$numero"';
        });
        return;
      }
      final client = await ref.read(clientRepositoryProvider).getById(compte.clientId);
      final solde = await ref.read(compteRepositoryProvider).getSolde(compte.id);
      setState(() {
        _isSearching = false;
        _compteTrouve = compte;
        _clientTrouve = client;
        _soldeTrouve = solde;
      });
    } catch (_) {
      setState(() {
        _isSearching = false;
        _errorMessage = 'Recherche impossible, réessayez';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Collecte rapide', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            "Saisissez le numéro de compte Sabotay du client (ex. SB-000042)",
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _numeroController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Numéro de compte',
                    hintText: 'SB-000042',
                  ),
                  onSubmitted: (_) => _rechercher(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _isSearching ? null : _rechercher,
                icon: _isSearching
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.search),
              ),
            ],
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(_errorMessage!, style: TextStyle(color: colorScheme.error)),
          ],
          if (_compteTrouve != null && _clientTrouve != null) ...[
            const SizedBox(height: 20),
            _CompteTrouveCard(
              client: _clientTrouve!,
              compte: _compteTrouve!,
              solde: _soldeTrouve,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                showAddCollecteSheet(
                  context,
                  _compteTrouve!,
                  clientNom: _clientTrouve!.nomComplet,
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Enregistrer une collecte'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                showRetraitSheet(
                  context,
                  _compteTrouve!,
                  clientNom: _clientTrouve!.nomComplet,
                );
              },
              icon: const Icon(Icons.arrow_upward),
              label: const Text('Effectuer un retrait'),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompteTrouveCard extends StatelessWidget {
  final Client client;
  final CompteSabotay compte;
  final CompteSolde? solde;

  const _CompteTrouveCard({required this.client, required this.compte, required this.solde});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final amountFormat = NumberFormat.decimalPattern('fr');
    final solde = this.solde;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: colorScheme.primary,
                child: Text(
                  client.prenom.isNotEmpty ? client.prenom[0].toUpperCase() : '?',
                  style: TextStyle(color: colorScheme.onPrimary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(client.nomComplet, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(client.telephone, style: TextStyle(color: colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Text('Compte ${compte.numeroCompte}', style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(
            '${compte.montantJournalier} HTG / jour',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          if (solde == null) ...[
            const SizedBox(height: 8),
            const SizedBox(
              height: 14,
              width: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ] else ...[
            const Divider(height: 20),
            Text(
              'Solde disponible : ${amountFormat.format(solde.soldeDisponible)} HTG',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (solde.joursManques > 0)
              Text(
                '${solde.joursManques} jour(s) manqué(s) — dette ${amountFormat.format(solde.dette)} HTG',
                style: TextStyle(fontSize: 12, color: colorScheme.error),
              ),
          ],
        ],
      ),
    );
  }
}
