class EntrepriseProfile {
  final String id;
  final String nom;
  final String devise;
  final String? adresse;
  final String? telephoneContact;
  final String formatRecu;
  final String? texteBasRecu;
  final String? logoData;
  final num fraisRetrait;
  final String statut;

  const EntrepriseProfile({
    required this.id,
    required this.nom,
    required this.devise,
    required this.adresse,
    required this.telephoneContact,
    required this.formatRecu,
    required this.texteBasRecu,
    required this.logoData,
    required this.fraisRetrait,
    required this.statut,
  });

  factory EntrepriseProfile.fromJson(Map<String, dynamic> json) => EntrepriseProfile(
        id: json['id'] as String,
        nom: json['nom'] as String,
        devise: json['devise'] as String,
        adresse: json['adresse'] as String?,
        telephoneContact: json['telephone_contact'] as String?,
        formatRecu: json['format_recu'] as String,
        texteBasRecu: json['texte_bas_recu'] as String?,
        logoData: json['logo_data'] as String?,
        fraisRetrait: num.parse(json['frais_retrait'].toString()),
        statut: json['statut'] as String,
      );
}
