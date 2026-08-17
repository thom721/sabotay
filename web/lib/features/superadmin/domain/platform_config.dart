/// Réglages globaux de la plateforme : abonnement (prix, essai) et email
/// SMTP dynamique (Paramètres → Email, super-admin) — voir
/// `core/notifications.py::send_email` côté backend.
class PlatformConfig {
  final int abonnementMontantHtg;
  // Prix du PROCHAIN renouvellement, distinct du prix courant — null si
  // aucun changement de prix n'est annoncé (le renouvellement se fait alors
  // au même prix que abonnementMontantHtg).
  final int? abonnementRenouvellementHtg;
  final int essaiJours;
  final String? smtpHost;
  final int smtpPort;
  final String? smtpUser;
  // Jamais le mot de passe réel — seulement s'il est défini ou non.
  final bool smtpPasswordDefini;
  final String? smtpFromEmail;

  const PlatformConfig({
    required this.abonnementMontantHtg,
    required this.abonnementRenouvellementHtg,
    required this.essaiJours,
    required this.smtpHost,
    required this.smtpPort,
    required this.smtpUser,
    required this.smtpPasswordDefini,
    required this.smtpFromEmail,
  });

  factory PlatformConfig.fromJson(Map<String, dynamic> json) => PlatformConfig(
        abonnementMontantHtg: json['abonnement_montant_htg'] as int,
        abonnementRenouvellementHtg: json['abonnement_renouvellement_htg'] as int?,
        essaiJours: json['essai_jours'] as int,
        smtpHost: json['smtp_host'] as String?,
        smtpPort: json['smtp_port'] as int,
        smtpUser: json['smtp_user'] as String?,
        smtpPasswordDefini: json['smtp_password_defini'] as bool,
        smtpFromEmail: json['smtp_from_email'] as String?,
      );
}
