import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../comptes/data/compte_repository.dart';
import '../data/client_repository.dart';
import '../domain/client.dart';
import 'client_detail_screen.dart';
import 'client_list_controller.dart';
import 'client_list_screen.dart';

final _dateFormat = DateFormat('dd/MM/yyyy');

/// Recherche d'un client par nom/prénom, date de naissance, ou numéro de
/// compte actif — remplace l'ancien accès direct à la liste complète depuis
/// l'accueil. Filtre en local sur la liste déjà chargée
/// (`clientListControllerProvider`, déjà filtrée par rôle côté backend) pour
/// nom/prénom/date de naissance ; un numéro de compte déclenche une
/// résolution directe via `GET /comptes/numero/{numero}` (déjà utilisé par
/// la collecte rapide).
Future<void> showClientSearchSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _ClientSearchSheet(),
  );
}

class _ClientSearchSheet extends ConsumerStatefulWidget {
  const _ClientSearchSheet();

  @override
  ConsumerState<_ClientSearchSheet> createState() => _ClientSearchSheetState();
}

class _ClientSearchSheetState extends ConsumerState<_ClientSearchSheet> {
  final _texteController = TextEditingController();
  DateTime? _dateNaissance;
  bool _isSearchingNumero = false;
  String? _erreurNumero;

  @override
  void dispose() {
    _texteController.dispose();
    super.dispose();
  }

  bool _ressembleANumeroCompte(String texte) =>
      texte.trim().toUpperCase().startsWith('SB-');

  Future<void> _rechercherParNumero() async {
    final numero = _texteController.text.trim().toUpperCase();
    setState(() {
      _isSearchingNumero = true;
      _erreurNumero = null;
    });
    try {
      final compte = await ref.read(compteRepositoryProvider).getByNumero(numero);
      if (compte == null) {
        setState(() {
          _isSearchingNumero = false;
          _erreurNumero = 'Aucun compte trouvé pour "$numero"';
        });
        return;
      }
      final client = await ref.read(clientRepositoryProvider).getById(compte.clientId);
      if (mounted) {
        setState(() => _isSearchingNumero = false);
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ClientDetailScreen(client: client)),
        );
      }
    } catch (_) {
      setState(() {
        _isSearchingNumero = false;
        _erreurNumero = 'Recherche impossible, réessayez';
      });
    }
  }

  Future<void> _choisirDateNaissance() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dateNaissance = picked);
  }

  List<Client> _filtrer(List<Client> clients) {
    final texte = _texteController.text.trim().toLowerCase();
    return clients.where((client) {
      final correspondTexte = texte.isEmpty ||
          client.nom.toLowerCase().contains(texte) ||
          client.prenom.toLowerCase().contains(texte);
      final correspondDate = _dateNaissance == null ||
          (client.dateNaissance != null &&
              client.dateNaissance!.year == _dateNaissance!.year &&
              client.dateNaissance!.month == _dateNaissance!.month &&
              client.dateNaissance!.day == _dateNaissance!.day);
      return correspondTexte && correspondDate;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final clientsAsync = ref.watch(clientListControllerProvider);
    final texte = _texteController.text.trim();
    final peutEtreNumero = _ressembleANumeroCompte(texte);

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
          Text('Rechercher un client', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _texteController,
                  decoration: const InputDecoration(
                    labelText: 'Nom, prénom ou numéro de compte',
                    hintText: 'ex. Marie ou SB-000042',
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) {
                    if (peutEtreNumero) _rechercherParNumero();
                  },
                ),
              ),
              if (peutEtreNumero) ...[
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _isSearchingNumero ? null : _rechercherParNumero,
                  icon: _isSearchingNumero
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.search),
                ),
              ],
            ],
          ),
          if (_erreurNumero != null) ...[
            const SizedBox(height: 8),
            Text(_erreurNumero!, style: TextStyle(color: colorScheme.error)),
          ],
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              _dateNaissance == null
                  ? 'Filtrer par date de naissance'
                  : 'Né(e) le ${_dateFormat.format(_dateNaissance!)}',
            ),
            trailing: _dateNaissance == null
                ? const Icon(Icons.calendar_today, size: 18)
                : IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _dateNaissance = null),
                  ),
            onTap: _choisirDateNaissance,
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: clientsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => const Text('Impossible de charger les clients'),
              data: (clients) {
                final resultats = _filtrer(clients);
                if (texte.isEmpty && _dateNaissance == null) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Tapez un nom ou choisissez une date pour filtrer.'),
                  );
                }
                if (resultats.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Aucun client ne correspond.'),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: resultats.length,
                  itemBuilder: (context, index) {
                    final client = resultats[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: colorScheme.primary,
                        child: Text(
                          client.prenom.isNotEmpty ? client.prenom[0].toUpperCase() : '?',
                          style: TextStyle(color: colorScheme.onPrimary),
                        ),
                      ),
                      title: Text(client.nomComplet),
                      subtitle: Text(client.telephone),
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => ClientDetailScreen(client: client)),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ClientListScreen()),
              );
            },
            child: const Text('Voir tous mes clients'),
          ),
        ],
      ),
    );
  }
}
