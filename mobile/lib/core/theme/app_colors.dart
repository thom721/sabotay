import 'package:flutter/material.dart';

/// Palette de marque SabotayPro — reprend telle quelle la palette de l'app
/// pos_api (`pos_api/frontend/lib/core/theme.dart::AppColors`), sur demande
/// explicite, à la place du système "navy/émeraude" de
/// Model_Mobil_App/DESIGN.md utilisé jusqu'ici. pos_api n'a qu'un seul thème
/// (pas de mode sombre) — les variantes `*Dark` ci-dessous sont donc
/// adaptées (pas copiées) pour rester lisibles sur fond sombre, en
/// réutilisant d'autres valeurs déjà définies par pos_api plutôt que d'en
/// inventer (ex. `navyDark` reprend `sidebarSelected`, la teinte que pos_api
/// utilise lui-même pour ressortir sur son fond de sidebar sombre).
/// Noms de constantes conservés à l'identique (navy/emerald/crimson/slate)
/// pour ne pas casser tous les points d'usage dans l'app — seules les
/// valeurs changent.
class AppColors {
  AppColors._();

  // primary (pos_api)
  static const navy = Color(0xFF0077C5);
  // sidebarSelected (pos_api) — bleu vif prévu par pos_api lui-même pour
  // rester lisible sur un fond sombre.
  static const navyDark = Color(0xFF2563EB);

  // accent (pos_api)
  static const emerald = Color(0xFF2CA01C);
  static const emeraldContainer = Color(0xFFC8F7CE);
  static const onEmeraldContainer = Color(0xFF1B5E20);
  // success (pos_api) — vert le plus proche déjà pensé par pos_api pour
  // rester lisible sur fond sombre/foncé (statut "payé").
  static const emeraldDark = Color(0xFF38A169);

  // error (pos_api)
  static const crimson = Color(0xFFE53E3E);
  static const crimsonContainer = Color(0xFFFFDAD6);
  static const onCrimsonContainer = Color(0xFF93000A);
  // Variante éclaircie (pos_api n'a pas de mode sombre) pour rester lisible
  // sur fond très sombre.
  static const crimsonDark = Color(0xFFFF6B6B);

  // info (pos_api) — même bleu déjà repris côté web (dashboard_screen.dart,
  // carte "Clients actifs") : palette cohérente entre web et mobile.
  static const slate = Color(0xFF3182CE);

  // background / surface / textPrimary / textSecondary / divider (pos_api)
  static const lightBg = Color(0xFFF0F2F5);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceContainerLow = Color(0xFFF2F4F6);
  static const lightSurfaceContainer = Color(0xFFECEEF0);
  static const lightSurfaceContainerHigh = Color(0xFFE6E8EA);
  static const lightSurfaceContainerHighest = Color(0xFFE0E3E5);
  static const lightOutline = Color(0xFFE2E8F0);
  static const lightOutlineVariant = Color(0xFFEDF0F3);
  static const lightInk = Color(0xFF1A202C);
  static const lightMuted = Color(0xFF718096);

  static const darkBg = Color(0xFF191C1E);
  static const darkSurface = Color(0xFF2D3133);
  static const darkSurfaceContainerLow = Color(0xFF23272A);
  static const darkSurfaceContainer = Color(0xFF282C2F);
  static const darkSurfaceContainerHigh = Color(0xFF333739);
  static const darkSurfaceContainerHighest = Color(0xFF3E4244);
  static const darkOutline = Color(0xFF8F9199);
  static const darkOutlineVariant = Color(0xFF44474D);
  static const darkInk = Color(0xFFEFF1F3);
  static const darkMuted = Color(0xFFC5C6CD);
}
