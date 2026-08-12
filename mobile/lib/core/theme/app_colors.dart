import 'package:flutter/material.dart';

/// Palette de marque SabotayPro — système Material 3 "navy/émeraude" défini
/// dans Model_Mobil_App/DESIGN.md : navy profond en accent principal
/// (autorité, navigation), vert émeraude réservé aux montants positifs et
/// aux actions de collecte, rouge crimson pour les alertes/retards.
class AppColors {
  AppColors._();

  static const navy = Color(0xFF0D1C32);
  static const navyDark = Color(0xFFB9C7E4);

  static const emerald = Color(0xFF006C49);
  static const emeraldContainer = Color(0xFF6CF8BB);
  static const onEmeraldContainer = Color(0xFF00714D);
  static const emeraldDark = Color(0xFF4EDEA3);

  static const crimson = Color(0xFFBA1A1A);
  static const crimsonContainer = Color(0xFFFFDAD6);
  static const onCrimsonContainer = Color(0xFF93000A);
  static const crimsonDark = Color(0xFFFFB4AB);

  static const slate = Color(0xFF44474D);

  static const lightBg = Color(0xFFF7F9FB);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceContainerLow = Color(0xFFF2F4F6);
  static const lightSurfaceContainer = Color(0xFFECEEF0);
  static const lightSurfaceContainerHigh = Color(0xFFE6E8EA);
  static const lightSurfaceContainerHighest = Color(0xFFE0E3E5);
  static const lightOutline = Color(0xFF75777E);
  static const lightOutlineVariant = Color(0xFFC5C6CD);
  static const lightInk = Color(0xFF191C1E);
  static const lightMuted = Color(0xFF44474D);

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
