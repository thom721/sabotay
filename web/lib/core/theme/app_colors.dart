import 'package:flutter/material.dart';

/// Palette de marque SabotayPro — reprend le fil "registre/tampon de
/// confiance" déjà établi sur la page publique : or-gourde en accent
/// principal, vert "vérifié" pour les états payés, rouge-tampon réservé
/// aux alertes/retards (jamais aux actions courantes, pour ne pas le
/// confondre avec l'accent principal).
class AppColors {
  AppColors._();

  static const gold = Color(0xFFB4802A);
  static const goldDark = Color(0xFFD9AE5C);

  static const verifiedGreen = Color(0xFF2F6B54);
  static const verifiedGreenDark = Color(0xFF5DAE8C);

  static const stampRed = Color(0xFFB33A2E);
  static const stampRedDark = Color(0xFFE2685A);

  static const lightBg = Color(0xFFFAF7F2);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceVariant = Color(0xFFF1EBDF);
  static const lightOutline = Color(0xFFE2D9C5);
  static const lightInk = Color(0xFF1C2333);
  static const lightMuted = Color(0xFF6B6455);

  static const darkBg = Color(0xFF14192B);
  static const darkSurface = Color(0xFF1B2036);
  static const darkSurfaceVariant = Color(0xFF232A44);
  static const darkOutline = Color(0xFF333B58);
  static const darkInk = Color(0xFFF0EAD9);
  static const darkMuted = Color(0xFFA79E86);
}
