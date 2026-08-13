enum TypeTransaction { collecte, retrait }

TypeTransaction typeTransactionFromString(String value) =>
    value == 'retrait' ? TypeTransaction.retrait : TypeTransaction.collecte;

String typeTransactionToApi(TypeTransaction type) =>
    type == TypeTransaction.retrait ? 'retrait' : 'collecte';

String typeTransactionLabel(TypeTransaction type) =>
    type == TypeTransaction.retrait ? 'Retrait' : 'Collecte';

class Transaction {
  final String id;
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
