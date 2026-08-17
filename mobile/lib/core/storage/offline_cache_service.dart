import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../features/clients/domain/client.dart';
import '../../features/comptes/domain/compte_sabotay.dart';
import '../../features/entreprise/domain/entreprise_profil.dart';
import '../../features/transactions/domain/transaction.dart';
import 'local_db_service.dart';

const _pageSize = 200;
// Plafond de pages pour l'historique des transactions — évite de retélé-
// charger des années d'historique à chaque sync ; le registre est trié par
// date décroissante (voir GET /transactions), donc ce plafond garde bien
// les transactions les plus RÉCENTES, pas un sous-ensemble arbitraire.
const _pagesMaxTransactions = 10;

/// Rafraîchit le cache local (SQLite, `LocalDbService`) depuis l'API —
/// clients, comptes Sabotay (avec solde), historique récent des
/// transactions, profil entreprise (Epic 6, offline-first mobile). Ne lève
/// jamais d'exception vers l'appelant : un échec de sync ne doit jamais
/// faire planter l'app, le cache existant (même daté) reste utilisable.
///
/// Appelé au login (premier remplissage) et par `OfflineDrainScope` (retour
/// au premier plan, timer périodique, retour réseau) — mêmes déclencheurs
/// que le drain de la file d'écritures, pas de nouveau mécanisme à part.
class OfflineCacheService {
  OfflineCacheService._();
  static final OfflineCacheService instance = OfflineCacheService._();

  bool _enCours = false;

  Future<void> syncAll(Dio dio) async {
    if (_enCours) return;
    _enCours = true;
    try {
      await Future.wait([
        _syncClients(dio),
        _syncComptes(dio),
        _syncTransactions(dio),
        _syncProfil(dio),
      ]);
    } finally {
      _enCours = false;
    }
  }

  Future<void> _syncClients(Dio dio) async {
    try {
      final response = await dio.get('/clients');
      final clients = (response.data as List)
          .map((json) => Client.fromJson(json as Map<String, dynamic>))
          .toList();
      await LocalDbService.instance.upsertClients(clients);
      await LocalDbService.instance.supprimerClientsAbsents(clients.map((c) => c.id).toList());
      await LocalDbService.instance.marquerSynchronise('clients');
    } catch (e) {
      debugPrint('[OfflineCache] échec sync clients: $e');
    }
  }

  Future<void> _syncComptes(Dio dio) async {
    try {
      final comptes = <CompteSabotayAvecSolde>[];
      var skip = 0;
      while (true) {
        final response = await dio.get('/comptes', queryParameters: {
          'skip': skip,
          'limit': _pageSize,
        });
        final data = response.data as Map<String, dynamic>;
        final page = (data['items'] as List)
            .map((json) => CompteSabotayAvecSolde.fromJson(json as Map<String, dynamic>))
            .toList();
        comptes.addAll(page);
        final total = data['total'] as int;
        skip += _pageSize;
        if (skip >= total || page.isEmpty) break;
      }
      await LocalDbService.instance.upsertComptes(comptes);
      await LocalDbService.instance
          .supprimerComptesAbsents(comptes.map((c) => c.compte.id).toList());
      await LocalDbService.instance.marquerSynchronise('comptes');
    } catch (e) {
      debugPrint('[OfflineCache] échec sync comptes: $e');
    }
  }

  Future<void> _syncTransactions(Dio dio) async {
    try {
      final transactions = <Transaction>[];
      var skip = 0;
      for (var page = 0; page < _pagesMaxTransactions; page++) {
        final response = await dio.get('/transactions', queryParameters: {
          'skip': skip,
          'limit': _pageSize,
        });
        final data = response.data as Map<String, dynamic>;
        // GET /transactions renvoie des champs en plus (client_nom,
        // compte_numero) — Transaction.fromJson ignore simplement les clés
        // qu'il ne connaît pas, pas besoin d'un modèle dédié côté mobile.
        final items = (data['items'] as List)
            .map((json) => Transaction.fromJson(json as Map<String, dynamic>))
            .toList();
        transactions.addAll(items);
        final total = data['total'] as int;
        skip += _pageSize;
        if (skip >= total || items.isEmpty) break;
      }
      await LocalDbService.instance.upsertTransactions(transactions);
      await LocalDbService.instance.marquerSynchronise('transactions');
    } catch (e) {
      debugPrint('[OfflineCache] échec sync transactions: $e');
    }
  }

  Future<void> _syncProfil(Dio dio) async {
    try {
      final response = await dio.get('/entreprises/profil');
      final profil = EntrepriseProfil.fromJson(response.data as Map<String, dynamic>);
      await LocalDbService.instance.upsertProfil(profil);
      await LocalDbService.instance.marquerSynchronise('entreprise_profil');
    } catch (e) {
      debugPrint('[OfflineCache] échec sync profil: $e');
    }
  }
}
