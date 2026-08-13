import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Piles de polices système (aucune dépendance réseau — la connectivité en
/// Haïti est une vraie contrainte produit, voir PRD §9).
class AppFonts {
  AppFonts._();

  static const display = 'Georgia';
  static const displayFallback = [
    'Iowan Old Style',
    'Palatino Linotype',
    'Times New Roman',
    'serif',
  ];

  static const body = 'Segoe UI';
  static const bodyFallback = ['Helvetica Neue', 'Arial', 'sans-serif'];

  static const mono = 'Consolas';
  static const monoFallback = ['SF Mono', 'Roboto Mono', 'monospace'];
}

class AppTheme {
  AppTheme._();

  static TextTheme _textTheme(Color ink) {
    const base = TextTheme(
      displayLarge: TextStyle(
        fontFamily: AppFonts.display,
        fontFamilyFallback: AppFonts.displayFallback,
      ),
      displayMedium: TextStyle(
        fontFamily: AppFonts.display,
        fontFamilyFallback: AppFonts.displayFallback,
      ),
      displaySmall: TextStyle(
        fontFamily: AppFonts.display,
        fontFamilyFallback: AppFonts.displayFallback,
      ),
      headlineLarge: TextStyle(
        fontFamily: AppFonts.display,
        fontFamilyFallback: AppFonts.displayFallback,
        fontWeight: FontWeight.bold,
      ),
      headlineMedium: TextStyle(
        fontFamily: AppFonts.display,
        fontFamilyFallback: AppFonts.displayFallback,
        fontWeight: FontWeight.bold,
      ),
      headlineSmall: TextStyle(
        fontFamily: AppFonts.display,
        fontFamilyFallback: AppFonts.displayFallback,
        fontWeight: FontWeight.bold,
      ),
      titleLarge: TextStyle(
        fontFamily: AppFonts.display,
        fontFamilyFallback: AppFonts.displayFallback,
        fontWeight: FontWeight.bold,
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
        letterSpacing: 0.4,
      ),
      labelSmall: TextStyle(
        fontFamily: AppFonts.body,
        fontFamilyFallback: AppFonts.bodyFallback,
        letterSpacing: 0.6,
      ),
    );
    return base.apply(bodyColor: ink, displayColor: ink);
  }

  /// Style pour les chiffres mis en avant (statistiques, montants) — police
  /// mono façon reçu/registre, cohérente avec la page publique.
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
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.gold,
      brightness: Brightness.light,
    );
    final colorScheme = base.copyWith(
      primary: AppColors.gold,
      onPrimary: Colors.white,
      secondary: AppColors.verifiedGreen,
      onSecondary: Colors.white,
      error: AppColors.stampRed,
      onError: Colors.white,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightInk,
      surfaceVariant: AppColors.lightSurfaceVariant,
      onSurfaceVariant: AppColors.lightMuted,
      outline: AppColors.lightOutline,
      background: AppColors.lightBg,
      onBackground: AppColors.lightInk,
    );
    return _build(colorScheme, scaffoldBg: AppColors.lightBg);
  }

  static ThemeData get dark {
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.goldDark,
      brightness: Brightness.dark,
    );
    final colorScheme = base.copyWith(
      primary: AppColors.goldDark,
      onPrimary: AppColors.darkBg,
      secondary: AppColors.verifiedGreenDark,
      onSecondary: AppColors.darkBg,
      error: AppColors.stampRedDark,
      onError: AppColors.darkBg,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkInk,
      surfaceVariant: AppColors.darkSurfaceVariant,
      onSurfaceVariant: AppColors.darkMuted,
      outline: AppColors.darkOutline,
      background: AppColors.darkBg,
      onBackground: AppColors.darkInk,
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
        backgroundColor: scaffoldBg,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: AppFonts.display,
          fontFamilyFallback: AppFonts.displayFallback,
          fontWeight: FontWeight.bold,
          fontSize: 20,
          color: colorScheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: colorScheme.outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: const OutlineInputBorder(),
        filled: true,
        // surfaceVariant, pas surface : un champ rempli de la même couleur
        // que la Card/le BottomSheet qui le contient (très fréquent dans
        // cette app — formulaires en Card ou en showModalBottomSheet) s'y
        // fond visuellement, ne laissant que le contour fin pour le
        // distinguer.
        fillColor: colorScheme.surfaceVariant,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          // Material 3 change ElevatedButton en bouton "tonal" discret par
          // défaut (fond surface teinté, texte primary, pas de fond plein)
          // — contrairement à Material 2, sans ces deux lignes tout bouton
          // d'action principale de l'app se fond dans l'arrière-plan et
          // ressemble à un simple lien texte (constaté sur l'écran de
          // connexion : "Se connecter" à peine distinguable de "Mot de passe
          // oublié ?"). Fond plein + texte contrastant = FilledButton de M3,
          // reproduit ici pour ne pas migrer tous les ElevatedButton du code.
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          // Largeur minimale finie : un Size.fromHeight (largeur infinie)
          // fait planter tout bouton placé dans une Row/Wrap plutôt qu'étiré
          // par une Column(crossAxisAlignment: stretch).
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
      dividerTheme: DividerThemeData(color: colorScheme.outline, space: 1),
    );
  }
}
