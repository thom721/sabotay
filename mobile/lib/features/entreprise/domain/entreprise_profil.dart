class EntrepriseProfil {
  final String id;
  final String nom;
  final String devise;
  final String? adresse;
  final String? telephoneContact;
  final String formatRecu;
  final String? texteBasRecu;
  final String? logoData;
  final num fraisRetrait;

  const EntrepriseProfil({
    required this.id,
    required this.nom,
    required this.devise,
    this.adresse,
    this.telephoneContact,
    required this.formatRecu,
    this.texteBasRecu,
    this.logoData,
    required this.fraisRetrait,
  });

  factory EntrepriseProfil.fromJson(Map<String, dynamic> json) => EntrepriseProfil(
        id: json['id'] as String,
        nom: json['nom'] as String,
        devise: json['devise'] as String,
        adresse: json['adresse'] as String?,
        telephoneContact: json['telephone_contact'] as String?,
        formatRecu: json['format_recu'] as String,
        texteBasRecu: json['texte_bas_recu'] as String?,
        logoData: json['logo_data'] as String?,
        fraisRetrait: num.parse(json['frais_retrait'].toString()),
      );
}
