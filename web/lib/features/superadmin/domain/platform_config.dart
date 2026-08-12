/// Réglages globaux de la plateforme : prix de l'abonnement annuel (HTG) et
/// durée de la période d'essai gratuit (jours), appliqués à toutes les
/// entreprises.
class PlatformConfig {
  final int abonnementMontantHtg;
  final int essaiJours;

  const PlatformConfig({required this.abonnementMontantHtg, required this.essaiJours});

  factory PlatformConfig.fromJson(Map<String, dynamic> json) => PlatformConfig(
        abonnementMontantHtg: json['abonnement_montant_htg'] as int,
        essaiJours: json['essai_jours'] as int,
      );
}
