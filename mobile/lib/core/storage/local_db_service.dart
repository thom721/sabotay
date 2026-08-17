import 'package:sqflite/sqflite.dart' hide Transaction;

import '../../features/clients/domain/client.dart';
import '../../features/comptes/domain/compte_sabotay.dart';
import '../../features/entreprise/domain/entreprise_profil.dart';
import '../../features/transactions/domain/transaction.dart';

/// Cache SQLite local — clients, comptes Sabotay (avec solde), historique
/// des transactions, profil entreprise (Epic 6, offline-first mobile).
/// Peuplé/rafraîchi par `OfflineCacheService`, consulté en priorité par les
/// repositories (`ClientRepository`, `CompteRepository`,
/// `TransactionRepository`, `EntrepriseRepository`) pour que l'app reste
/// utilisable sans réseau une fois le cache initialement chargé.
///
/// Les montants sont stockés en TEXT (pas REAL) — reflète tel quel la chaîne
/// Decimal renvoyée par le backend (`"250.00"`), sans introduire de perte de
/// précision supplémentaire par rapport à ce que fait déjà le reste de
/// l'app (`num.parse(json['x'].toString())` partout, jamais de type
/// Decimal côté Dart). Le cache n'est de toute façon jamais la source
/// d'autorité — le serveur revalide toujours au moment d'écrire.
class LocalDbService {
  LocalDbService._();
  static final LocalDbService instance = LocalDbService._();

  Database? _db;

  Future<Database> get _database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    return openDatabase(
      'sabotay_cache.db',
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE clients (
            id TEXT PRIMARY KEY,
            entreprise_id TEXT NOT NULL,
            nom TEXT NOT NULL,
            prenom TEXT NOT NULL,
            telephone TEXT NOT NULL,
            adresse TEXT,
            date_naissance TEXT,
            nif_cin TEXT,
            photo_url TEXT,
            email TEXT,
            agent_assigne_id TEXT,
            derniere_connexion TEXT,
            heritier_nom TEXT,
            heritier_prenom TEXT,
            heritier_adresse TEXT,
            heritier_telephone TEXT,
            statut TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE comptes_sabotay (
            id TEXT PRIMARY KEY,
            entreprise_id TEXT NOT NULL,
            client_id TEXT NOT NULL,
            numero_compte TEXT NOT NULL,
            montant_journalier TEXT NOT NULL,
            date_debut TEXT NOT NULL,
            duree_jours INTEGER NOT NULL,
            date_fin_prevue TEXT NOT NULL,
            montant_total_attendu TEXT NOT NULL,
            statut TEXT NOT NULL,
            montant_collecte TEXT NOT NULL,
            montant_retire TEXT NOT NULL,
            solde_restant TEXT NOT NULL,
            solde_disponible TEXT NOT NULL,
            dette TEXT NOT NULL,
            jours_manques INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE transactions_cache (
            id TEXT PRIMARY KEY,
            numero TEXT NOT NULL,
            entreprise_id TEXT NOT NULL,
            compte_id TEXT NOT NULL,
            date TEXT NOT NULL,
            montant TEXT NOT NULL,
            type TEXT NOT NULL,
            nb_jours INTEGER,
            frais TEXT,
            collecte_par_id TEXT NOT NULL,
            collecte_par_nom TEXT NOT NULL,
            cree_le TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE entreprise_profil (
            id TEXT PRIMARY KEY,
            nom TEXT NOT NULL,
            devise TEXT NOT NULL,
            adresse TEXT,
            telephone_contact TEXT,
            format_recu TEXT NOT NULL,
            texte_bas_recu TEXT,
            logo_data TEXT,
            frais_retrait TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE sync_meta (
            entity_type TEXT PRIMARY KEY,
            last_synced_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // ── sync_meta ────────────────────────────────────────────────────────────

  Future<void> marquerSynchronise(String entityType) async {
    final db = await _database;
    await db.insert(
      'sync_meta',
      {'entity_type': entityType, 'last_synced_at': DateTime.now().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<DateTime?> derniereSynchro(String entityType) async {
    final db = await _database;
    final rows = await db.query(
      'sync_meta',
      where: 'entity_type = ?',
      whereArgs: [entityType],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DateTime.tryParse(rows.first['last_synced_at'] as String);
  }

  // ── Clients ──────────────────────────────────────────────────────────────

  Map<String, dynamic> _clientToRow(Client c) => {
        'id': c.id,
        'entreprise_id': c.entrepriseId,
        'nom': c.nom,
        'prenom': c.prenom,
        'telephone': c.telephone,
        'adresse': c.adresse,
        'date_naissance': c.dateNaissance?.toIso8601String(),
        'nif_cin': c.nifCin,
        'photo_url': c.photoUrl,
        'email': c.email,
        'agent_assigne_id': c.agentAssigneId,
        'derniere_connexion': c.derniereConnexion?.toIso8601String(),
        'heritier_nom': c.heritierNom,
        'heritier_prenom': c.heritierPrenom,
        'heritier_adresse': c.heritierAdresse,
        'heritier_telephone': c.heritierTelephone,
        'statut': c.statut.name,
      };

  Client _clientFromRow(Map<String, Object?> r) => Client(
        id: r['id'] as String,
        entrepriseId: r['entreprise_id'] as String,
        nom: r['nom'] as String,
        prenom: r['prenom'] as String,
        telephone: r['telephone'] as String,
        adresse: r['adresse'] as String?,
        dateNaissance:
            r['date_naissance'] != null ? DateTime.tryParse(r['date_naissance'] as String) : null,
        nifCin: r['nif_cin'] as String?,
        photoUrl: r['photo_url'] as String?,
        email: r['email'] as String?,
        agentAssigneId: r['agent_assigne_id'] as String?,
        derniereConnexion: r['derniere_connexion'] != null
            ? DateTime.tryParse(r['derniere_connexion'] as String)
            : null,
        heritierNom: r['heritier_nom'] as String?,
        heritierPrenom: r['heritier_prenom'] as String?,
        heritierAdresse: r['heritier_adresse'] as String?,
        heritierTelephone: r['heritier_telephone'] as String?,
        statut: statutClientFromString(r['statut'] as String),
      );

  Future<void> upsertClients(List<Client> clients) async {
    final db = await _database;
    final batch = db.batch();
    for (final c in clients) {
      batch.insert('clients', _clientToRow(c), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// Purge les clients qui ne sont plus renvoyés par le serveur (supprimés,
  /// ou plus assignés à cet agent) — même logique diff-et-purge qu'un cache
  /// classique, sans quoi un client réassigné ailleurs resterait visible
  /// indéfiniment hors-ligne.
  Future<void> supprimerClientsAbsents(List<String> idsServeur) async {
    final db = await _database;
    if (idsServeur.isEmpty) {
      await db.delete('clients');
      return;
    }
    final placeholders = List.filled(idsServeur.length, '?').join(',');
    await db.delete('clients', where: 'id NOT IN ($placeholders)', whereArgs: idsServeur);
  }

  Future<List<Client>> getClients() async {
    final db = await _database;
    final rows = await db.query('clients', orderBy: 'nom, prenom');
    return rows.map(_clientFromRow).toList();
  }

  Future<Client?> getClient(String id) async {
    final db = await _database;
    final rows = await db.query('clients', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return _clientFromRow(rows.first);
  }

  // ── Comptes Sabotay ──────────────────────────────────────────────────────

  Map<String, dynamic> _compteToRow(CompteSabotayAvecSolde c) => {
        'id': c.compte.id,
        'entreprise_id': c.compte.entrepriseId,
        'client_id': c.compte.clientId,
        'numero_compte': c.compte.numeroCompte,
        'montant_journalier': c.compte.montantJournalier.toString(),
        'date_debut': c.compte.dateDebut.toIso8601String(),
        'duree_jours': c.compte.dureeJours,
        'date_fin_prevue': c.compte.dateFinPrevue.toIso8601String(),
        'montant_total_attendu': c.compte.montantTotalAttendu.toString(),
        'statut': c.compte.statut.name,
        'montant_collecte': c.solde.montantCollecte.toString(),
        'montant_retire': c.solde.montantRetire.toString(),
        'solde_restant': c.solde.soldeRestant.toString(),
        'solde_disponible': c.solde.soldeDisponible.toString(),
        'dette': c.solde.dette.toString(),
        'jours_manques': c.solde.joursManques,
      };

  CompteSabotay _compteFromRow(Map<String, Object?> r) => CompteSabotay(
        id: r['id'] as String,
        entrepriseId: r['entreprise_id'] as String,
        clientId: r['client_id'] as String,
        numeroCompte: r['numero_compte'] as String,
        montantJournalier: num.parse(r['montant_journalier'] as String),
        dateDebut: DateTime.parse(r['date_debut'] as String),
        dureeJours: r['duree_jours'] as int,
        dateFinPrevue: DateTime.parse(r['date_fin_prevue'] as String),
        montantTotalAttendu: num.parse(r['montant_total_attendu'] as String),
        statut: statutCompteFromString(r['statut'] as String),
      );

  CompteSolde _soldeFromRow(Map<String, Object?> r) => CompteSolde(
        compteId: r['id'] as String,
        montantTotalAttendu: num.parse(r['montant_total_attendu'] as String),
        montantCollecte: num.parse(r['montant_collecte'] as String),
        montantRetire: num.parse(r['montant_retire'] as String),
        soldeRestant: num.parse(r['solde_restant'] as String),
        soldeDisponible: num.parse(r['solde_disponible'] as String),
        dette: num.parse(r['dette'] as String),
        joursManques: r['jours_manques'] as int,
      );

  Future<void> upsertComptes(List<CompteSabotayAvecSolde> comptes) async {
    final db = await _database;
    final batch = db.batch();
    for (final c in comptes) {
      batch.insert('comptes_sabotay', _compteToRow(c),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> supprimerComptesAbsents(List<String> idsServeur) async {
    final db = await _database;
    if (idsServeur.isEmpty) {
      await db.delete('comptes_sabotay');
      return;
    }
    final placeholders = List.filled(idsServeur.length, '?').join(',');
    await db.delete('comptes_sabotay', where: 'id NOT IN ($placeholders)', whereArgs: idsServeur);
  }

  Future<List<CompteSabotay>> getComptesForClient(String clientId) async {
    final db = await _database;
    final rows = await db.query('comptes_sabotay', where: 'client_id = ?', whereArgs: [clientId]);
    return rows.map(_compteFromRow).toList();
  }

  Future<CompteSolde?> getSolde(String compteId) async {
    final db = await _database;
    final rows = await db.query('comptes_sabotay', where: 'id = ?', whereArgs: [compteId], limit: 1);
    if (rows.isEmpty) return null;
    return _soldeFromRow(rows.first);
  }

  Future<CompteSabotay?> getCompteParNumero(String numeroCompte) async {
    final db = await _database;
    final rows = await db.query(
      'comptes_sabotay',
      where: 'numero_compte = ?',
      whereArgs: [numeroCompte],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _compteFromRow(rows.first);
  }

  // ── Transactions ─────────────────────────────────────────────────────────

  Map<String, dynamic> _transactionToRow(Transaction t) => {
        'id': t.id,
        'numero': t.numero,
        'entreprise_id': t.entrepriseId,
        'compte_id': t.compteId,
        'date': t.date.toIso8601String(),
        'montant': t.montant.toString(),
        'type': typeTransactionToApi(t.type),
        'nb_jours': t.nbJours,
        'frais': t.frais?.toString(),
        'collecte_par_id': t.collecteParId,
        'collecte_par_nom': t.collecteParNom,
        'cree_le': t.creeLe.toIso8601String(),
      };

  Transaction _transactionFromRow(Map<String, Object?> r) => Transaction(
        id: r['id'] as String,
        numero: r['numero'] as String,
        entrepriseId: r['entreprise_id'] as String,
        compteId: r['compte_id'] as String,
        date: DateTime.parse(r['date'] as String),
        montant: num.parse(r['montant'] as String),
        type: typeTransactionFromString(r['type'] as String),
        nbJours: r['nb_jours'] as int?,
        frais: r['frais'] != null ? num.parse(r['frais'] as String) : null,
        collecteParId: r['collecte_par_id'] as String,
        collecteParNom: r['collecte_par_nom'] as String,
        creeLe: DateTime.parse(r['cree_le'] as String),
      );

  Future<void> upsertTransactions(List<Transaction> transactions) async {
    final db = await _database;
    final batch = db.batch();
    for (final t in transactions) {
      batch.insert('transactions_cache', _transactionToRow(t),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Transaction>> getTransactionsForCompte(String compteId) async {
    final db = await _database;
    final rows = await db.query(
      'transactions_cache',
      where: 'compte_id = ?',
      whereArgs: [compteId],
      orderBy: 'date DESC',
    );
    return rows.map(_transactionFromRow).toList();
  }

  // ── Profil entreprise (ligne singleton par tenant) ──────────────────────

  Future<void> upsertProfil(EntrepriseProfil p) async {
    final db = await _database;
    await db.insert(
      'entreprise_profil',
      {
        'id': p.id,
        'nom': p.nom,
        'devise': p.devise,
        'adresse': p.adresse,
        'telephone_contact': p.telephoneContact,
        'format_recu': p.formatRecu,
        'texte_bas_recu': p.texteBasRecu,
        'logo_data': p.logoData,
        'frais_retrait': p.fraisRetrait.toString(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<EntrepriseProfil?> getProfil() async {
    final db = await _database;
    final rows = await db.query('entreprise_profil', limit: 1);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return EntrepriseProfil(
      id: r['id'] as String,
      nom: r['nom'] as String,
      devise: r['devise'] as String,
      adresse: r['adresse'] as String?,
      telephoneContact: r['telephone_contact'] as String?,
      formatRecu: r['format_recu'] as String,
      texteBasRecu: r['texte_bas_recu'] as String?,
      logoData: r['logo_data'] as String?,
      fraisRetrait: num.parse(r['frais_retrait'] as String),
    );
  }

  // ── Vidage complet (changement de tenant, Epic 21) ─────────────────────

  Future<void> viderTout() async {
    final db = await _database;
    final batch = db.batch();
    for (final table in [
      'clients',
      'comptes_sabotay',
      'transactions_cache',
      'entreprise_profil',
      'sync_meta',
    ]) {
      batch.delete(table);
    }
    await batch.commit(noResult: true);
  }
}
