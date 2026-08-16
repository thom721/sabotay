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

  // Tailles reprises telles quelles de pos_api (core/theme.dart, _T.t(...))
  // pour les styles qu'il définit explicitement — display large/medium,
  // title large/medium, body large/medium/small, label large. Les autres
  // (headline*, displaySmall, titleSmall, labelMedium/Small), non couverts
  // par pos_api, gardent l'échelle Material 3 par défaut déjà en place.
  static TextTheme _textTheme(Color ink, Color muted) {
    const base = TextTheme(
      displayLarge: TextStyle(
        fontFamily: AppFonts.body,
        fontFamilyFallback: AppFonts.bodyFallback,
        fontSize: 32,
        fontWeight: FontWeight.w700,
      ),
      displayMedium: TextStyle(
        fontFamily: AppFonts.body,
        fontFamilyFallback: AppFonts.bodyFallback,
        fontSize: 24,
        fontWeight: FontWeight.w700,
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
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        fontFamily: AppFonts.body,
        fontFamilyFallback: AppFonts.bodyFallback,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: TextStyle(
        fontFamily: AppFonts.body,
        fontFamilyFallback: AppFonts.bodyFallback,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        fontFamily: AppFonts.body,
        fontFamilyFallback: AppFonts.bodyFallback,
        fontSize: 15,
      ),
      bodyMedium: TextStyle(
        fontFamily: AppFonts.body,
        fontFamilyFallback: AppFonts.bodyFallback,
        fontSize: 14,
      ),
      bodySmall: TextStyle(
        fontFamily: AppFonts.body,
        fontFamilyFallback: AppFonts.bodyFallback,
        fontSize: 12,
      ),
      labelLarge: TextStyle(
        fontFamily: AppFonts.body,
        fontFamilyFallback: AppFonts.bodyFallback,
        fontSize: 14,
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
    // bodySmall en couleur atténuée (textSecondary côté pos_api) — appliqué
    // après .apply() qui, sinon, écraserait cette couleur avec `ink` comme
    // tous les autres styles.
    return base.apply(bodyColor: ink, displayColor: ink).copyWith(
          bodySmall: base.bodySmall?.copyWith(color: muted),
        );
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
      textTheme: _textTheme(colorScheme.onSurface, colorScheme.onSurfaceVariant),
      // toolbarHeight/scrolledUnderElevation/surfaceTintColor : valeurs
      // reprises telles quelles de pos_api (core/theme.dart::AppTheme.light,
      // appBarTheme) — sans surfaceTintColor: transparent, Material 3 teinte
      // l'AppBar quand le contenu défile dessous (scrolledUnderElevation).
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 64,
        titleTextStyle: TextStyle(
          fontFamily: AppFonts.body,
          fontFamilyFallback: AppFonts.bodyFallback,
          fontWeight: FontWeight.w600,
          fontSize: 18,
          color: colorScheme.onSurface,
        ),
      ),
      // Rayon 12 + bordure fine + margin zéro : valeurs pos_api telles
      // quelles (radius 16 et pas de margin explicite auparavant).
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      // Fond blanc (surface) + bordure colorée, comme pos_api — remplace
      // l'ancien choix "fillColor: surfaceVariant" (Epic 4) qui distinguait
      // un champ de sa Card/BottomSheet par une teinte de fond ; ici c'est
      // la bordure qui joue ce rôle à la place, à l'identique de pos_api.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(
          fontFamily: AppFonts.body,
          fontFamilyFallback: AppFonts.bodyFallback,
          color: colorScheme.onSurfaceVariant,
        ),
        labelStyle: TextStyle(
          fontFamily: AppFonts.body,
          fontFamilyFallback: AppFonts.bodyFallback,
          color: colorScheme.onSurfaceVariant,
        ),
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
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          // Largeur minimale finie : un Size.fromHeight (largeur infinie)
          // fait planter tout bouton placé dans une Row/Wrap plutôt qu'étiré
          // par une Column(crossAxisAlignment: stretch).
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      // Absent jusqu'ici — pos_api en définit un explicitement.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.primary),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      // Rectangle à coins légèrement arrondis (radius 6), comme pos_api —
      // remplace l'ancienne forme "pilule" (radius 999) utilisée jusqu'ici.
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        side: BorderSide.none,
      ),
      dividerTheme: DividerThemeData(color: colorScheme.outlineVariant, space: 1),
    );
  }
}
