import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Piles de polices système (aucune dépendance réseau — la connectivité en
/// Haïti est une vraie contrainte produit, voir PRD §9). Le design système
/// (Model_Mobil_App/DESIGN.md) prescrit Inter partout ; à défaut de pouvoir
/// l'embarquer sans appel réseau, on retombe sur la pile grotesque système
/// la plus proche visuellement (Roboto/Helvetica/Arial).
class AppFonts {
  AppFonts._();

  static const body = 'Roboto';
  static const bodyFallback = ['Helvetica Neue', 'Arial', 'sans-serif'];

  static const mono = 'Menlo';
  static const monoFallback = ['Consolas', 'Roboto Mono', 'monospace'];
}

class AppTheme {
  AppTheme._();

  static TextTheme _textTheme(Color ink) {
    const base = TextTheme(
      displayLarge: TextStyle(
        fontFamily: AppFonts.body,
        fontFamilyFallback: AppFonts.bodyFallback,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.02,
      ),
      displayMedium: TextStyle(
        fontFamily: AppFonts.body,
        fontFamilyFallback: AppFonts.bodyFallback,
        fontWeight: FontWeight.bold,
      ),
      displaySmall: TextStyle(fontFamily: AppFonts.body, fontFamilyFallback: AppFonts.bodyFallback),
      headlineLarge: TextStyle(
        fontFamily: AppFonts.body,
        fontFamilyFallback: AppFonts.bodyFallback,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.01,
      ),
      headlineMedium: TextStyle(
        fontFamily: AppFonts.body,
        fontFamilyFallback: AppFonts.bodyFallback,
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: TextStyle(
        fontFamily: AppFonts.body,
        fontFamilyFallback: AppFonts.bodyFallback,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: TextStyle(
        fontFamily: AppFonts.body,
        fontFamilyFallback: AppFonts.bodyFallback,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        fontFamily: AppFonts.body,
        fontFamilyFallback: AppFonts.bodyFallback,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: TextStyle(
        fontFamily: AppFonts.body,
        fontFamilyFallback: AppFonts.bodyFallback,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(fontFamily: AppFonts.body, fontFamilyFallback: AppFonts.bodyFallback),
      bodyMedium: TextStyle(fontFamily: AppFonts.body, fontFamilyFallback: AppFonts.bodyFallback),
      bodySmall: TextStyle(fontFamily: AppFonts.body, fontFamilyFallback: AppFonts.bodyFallback),
      labelLarge: TextStyle(
        fontFamily: AppFonts.body,
        fontFamilyFallback: AppFonts.bodyFallback,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: TextStyle(
        fontFamily: AppFonts.body,
        fontFamilyFallback: AppFonts.bodyFallback,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
      labelSmall: TextStyle(
        fontFamily: AppFonts.body,
        fontFamilyFallback: AppFonts.bodyFallback,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
    return base.apply(bodyColor: ink, displayColor: ink);
  }

  /// Style pour les chiffres mis en avant (statistiques, montants) — police
  /// mono façon registre, chiffres tabulaires pour l'alignement en colonnes.
  static TextStyle statNumberStyle(BuildContext context, {double fontSize = 28}) {
    return TextStyle(
      fontFamily: AppFonts.mono,
      fontFamilyFallback: AppFonts.monoFallback,
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      color: Theme.of(context).colorScheme.onSurface,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(seedColor: AppColors.navy, brightness: Brightness.light).copyWith(
      primary: AppColors.navy,
      onPrimary: Colors.white,
      primaryContainer: AppColors.navy,
      onPrimaryContainer: Colors.white,
      secondary: AppColors.emerald,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.emeraldContainer,
      onSecondaryContainer: AppColors.onEmeraldContainer,
      tertiary: AppColors.slate,
      onTertiary: Colors.white,
      error: AppColors.crimson,
      onError: Colors.white,
      errorContainer: AppColors.crimsonContainer,
      onErrorContainer: AppColors.onCrimsonContainer,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightInk,
      background: AppColors.lightBg,
      onBackground: AppColors.lightInk,
      surfaceVariant: AppColors.lightSurfaceContainerHighest,
      onSurfaceVariant: AppColors.lightMuted,
      outline: AppColors.lightOutline,
      outlineVariant: AppColors.lightOutlineVariant,
    );
    return _build(colorScheme, scaffoldBg: AppColors.lightBg);
  }

  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(seedColor: AppColors.navyDark, brightness: Brightness.dark).copyWith(
      primary: AppColors.navyDark,
      onPrimary: AppColors.navy,
      primaryContainer: AppColors.navyDark,
      onPrimaryContainer: AppColors.navy,
      secondary: AppColors.emeraldDark,
      onSecondary: AppColors.darkBg,
      secondaryContainer: AppColors.emerald,
      onSecondaryContainer: AppColors.emeraldContainer,
      tertiary: AppColors.darkMuted,
      onTertiary: AppColors.darkBg,
      error: AppColors.crimsonDark,
      onError: AppColors.darkBg,
      errorContainer: AppColors.onCrimsonContainer,
      onErrorContainer: AppColors.crimsonContainer,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkInk,
      background: AppColors.darkBg,
      onBackground: AppColors.darkInk,
      surfaceVariant: AppColors.darkSurfaceContainerHigh,
      onSurfaceVariant: AppColors.darkMuted,
      outline: AppColors.darkOutline,
      outlineVariant: AppColors.darkOutlineVariant,
    );
    return _build(colorScheme, scaffoldBg: AppColors.darkBg);
  }

  static ThemeData _build(ColorScheme colorScheme, {required Color scaffoldBg}) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBg,
      textTheme: _textTheme(colorScheme.onSurface),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: AppFonts.body,
          fontFamilyFallback: AppFonts.bodyFallback,
          fontWeight: FontWeight.bold,
          fontSize: 20,
          color: colorScheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        // surfaceVariant, pas surface : un champ rempli de la même couleur
        // que la Card/le BottomSheet qui le contient (formulaires en
        // showModalBottomSheet, très fréquent côté mobile) s'y fond
        // visuellement, ne laissant que le contour fin pour le distinguer.
        fillColor: colorScheme.surfaceVariant,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          // Material 3 change ElevatedButton en bouton "tonal" discret par
          // défaut (fond surface teinté, texte primary, pas de fond plein)
          // — sans ces deux lignes tout bouton d'action principale de l'app
          // se fond dans l'arrière-plan (même bug constaté et corrigé côté
          // web, voir son app_theme.dart).
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          // Largeur minimale finie : un Size.fromHeight (largeur infinie)
          // fait planter tout bouton placé dans une Row/Wrap plutôt qu'étiré
          // par une Column(crossAxisAlignment: stretch).
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide.none,
      ),
      dividerTheme: DividerThemeData(color: colorScheme.outlineVariant, space: 1),
    );
  }
}
