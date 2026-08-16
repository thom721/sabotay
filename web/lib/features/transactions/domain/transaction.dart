enum TypeTransaction { collecte, retrait }

TypeTransaction typeTransactionFromString(String value) =>
    value == 'retrait' ? TypeTransaction.retrait : TypeTransaction.collecte;

String typeTransactionToApi(TypeTransaction type) =>
    type == TypeTransaction.retrait ? 'retrait' : 'collecte';

String typeTransactionLabel(TypeTransaction type) =>
    type == TypeTransaction.retrait ? 'Retrait' : 'Collecte';

class Transaction {
  final String id;
  final String numero;
  final String entrepriseId;
  final String compteId;
  final DateTime date;
  final num montant;
  final TypeTransaction type;
  final int? nbJours;
  final num? frais;
  final String collecteParId;
  final String collecteParNom;
  final DateTime creeLe;

  const Transaction({
    required this.id,
    required this.numero,
    required this.entrepriseId,
    required this.compteId,
    required this.date,
    required this.montant,
    required this.type,
    this.nbJours,
    this.frais,
    required this.collecteParId,
    required this.collecteParNom,
    required this.creeLe,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        id: json['id'] as String,
        numero: json['numero'] as String,
        entrepriseId: json['entreprise_id'] as String,
        compteId: json['compte_id'] as String,
        date: DateTime.parse(json['date'] as String),
        montant: num.parse(json['montant'].toString()),
        type: typeTransactionFromString(json['type'] as String),
        nbJours: json['nb_jours'] as int?,
        frais: json['frais'] != null ? num.parse(json['frais'].toString()) : null,
        collecteParId: json['collecte_par_id'] as String,
        collecteParNom: json['collecte_par_nom'] as String,
        creeLe: DateTime.parse(json['cree_le'] as String),
      );
}

/// Rapport de collecte/retrait sur une période (PRD §8.7) — Admin/Manager
/// voient tout le tenant par défaut, ou un agent précis via un filtre
/// (`GET /transactions/rapport?agent_id=...`).
class Rapport {
  final DateTime dateDebut;
  final DateTime dateFin;
  final num totalCollecte;
  final num totalRetrait;
  final int nbTransactions;
  final List<Transaction> transactions;

  const Rapport({
    required this.dateDebut,
    required this.dateFin,
    required this.totalCollecte,
    required this.totalRetrait,
    required this.nbTransactions,
    required this.transactions,
  });

  factory Rapport.fromJson(Map<String, dynamic> json) => Rapport(
        dateDebut: DateTime.parse(json['date_debut'] as String),
        dateFin: DateTime.parse(json['date_fin'] as String),
        totalCollecte: num.parse(json['total_collecte'].toString()),
        totalRetrait: num.parse(json['total_retrait'].toString()),
        nbTransactions: json['nb_transactions'] as int,
        transactions: (json['transactions'] as List)
            .map((t) => Transaction.fromJson(t as Map<String, dynamic>))
            .toList(),
      );
}

/// Ligne du registre de transactions (`GET /transactions`) — même modèle que
/// [Transaction], enrichi du nom du client et du numéro de compte résolus
/// côté serveur (recherche libre par client/compte/agent, PRD Transactions).
class TransactionRegistreItem extends Transaction {
  final String clientNom;
  final String compteNumero;

  const TransactionRegistreItem({
    required super.id,
    required super.numero,
    required super.entrepriseId,
    required super.compteId,
    required super.date,
    required super.montant,
    required super.type,
    super.nbJours,
    super.frais,
    required super.collecteParId,
    required super.collecteParNom,
    required super.creeLe,
    required this.clientNom,
    required this.compteNumero,
  });

  factory TransactionRegistreItem.fromJson(Map<String, dynamic> json) => TransactionRegistreItem(
        id: json['id'] as String,
        numero: json['numero'] as String,
        entrepriseId: json['entreprise_id'] as String,
        compteId: json['compte_id'] as String,
        date: DateTime.parse(json['date'] as String),
        montant: num.parse(json['montant'].toString()),
        type: typeTransactionFromString(json['type'] as String),
        nbJours: json['nb_jours'] as int?,
        frais: json['frais'] != null ? num.parse(json['frais'].toString()) : null,
        collecteParId: json['collecte_par_id'] as String,
        collecteParNom: json['collecte_par_nom'] as String,
        creeLe: DateTime.parse(json['cree_le'] as String),
        clientNom: json['client_nom'] as String,
        compteNumero: json['compte_numero'] as String,
      );
}

class RegistrePage {
  final List<TransactionRegistreItem> items;
  final int total;

  const RegistrePage({required this.items, required this.total});

  factory RegistrePage.fromJson(Map<String, dynamic> json) => RegistrePage(
        items: (json['items'] as List)
            .map((t) => TransactionRegistreItem.fromJson(t as Map<String, dynamic>))
            .toList(),
        total: json['total'] as int,
      );
}
