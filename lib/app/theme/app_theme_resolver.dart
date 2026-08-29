import 'package:flutter/material.dart';

import '../../core/settings/appearance_settings.dart';
import 'app_theme.dart';

abstract final class AppThemeResolver {
  // ===================================================================
  // APP THEMES
  // ===================================================================

  static ThemeData light(AppearanceSettings settings) {
    return _resolve(settings, Brightness.light);
  }

  static ThemeData dark(AppearanceSettings settings) {
    return _resolve(settings, Brightness.dark);
  }

  // ===================================================================
  // CUSTOM PREVIEW
  // ===================================================================

  static ThemeData customPreview({
    required Color seedColor,
    required Color accentColor,
    required double backgroundStrength,
    required Brightness brightness,
  }) {
    return _seedTheme(
      seedColor: seedColor,
      accentColor: accentColor,
      backgroundStrength: backgroundStrength,
      brightness: brightness,
    );
  }

  // ===================================================================
  // RESOLVE
  // ===================================================================

  static ThemeData _resolve(
    AppearanceSettings settings,
    Brightness brightness,
  ) {
    switch (settings.preset) {
      // ---------------------------------------------------------------
      // ORIGINAL LINSY
      // ---------------------------------------------------------------

      case AppThemePreset.linsy:
        return brightness == Brightness.light ? AppTheme.light : AppTheme.dark;

      // ---------------------------------------------------------------
      // LAVENDER
      // ---------------------------------------------------------------

      case AppThemePreset.lavender:
        return _seedTheme(
          seedColor: const Color(0xFF9A7BEF),
          brightness: brightness,
          lightBackground: const Color(0xFFF3EEFF),
          darkBackground: const Color(0xFF171321),
        );

      // ---------------------------------------------------------------
      // ROSE
      // ---------------------------------------------------------------

      case AppThemePreset.rose:
        return _seedTheme(
          seedColor: const Color(0xFFE05D8A),
          brightness: brightness,
          lightBackground: const Color(0xFFFFF0F5),
          darkBackground: const Color(0xFF211217),
        );

      // ---------------------------------------------------------------
      // OCEAN
      // ---------------------------------------------------------------

      case AppThemePreset.ocean:
        return _seedTheme(
          seedColor: const Color(0xFF3E82D7),
          brightness: brightness,
          lightBackground: const Color(0xFFEDF6FF),
          darkBackground: const Color(0xFF101A24),
        );

      // ---------------------------------------------------------------
      // CUSTOM
      // ---------------------------------------------------------------

      case AppThemePreset.custom:
        return _seedTheme(
          seedColor: settings.customSeedColor,
          accentColor: settings.customAccentColor,
          backgroundStrength: settings.customBackgroundStrength,
          brightness: brightness,
        );
    }
  }

  // ===================================================================
  // GENERATED THEME
  // ===================================================================

  static ThemeData _seedTheme({
    required Color seedColor,
    required Brightness brightness,
    Color? accentColor,
    double? backgroundStrength,
    Color? lightBackground,
    Color? darkBackground,
  }) {
    final primaryScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );

    final accentScheme = ColorScheme.fromSeed(
      seedColor: accentColor ?? seedColor,
      brightness: brightness,
    );

    final colorScheme = primaryScheme.copyWith(
      secondary: accentScheme.primary,
      onSecondary: accentScheme.onPrimary,

      secondaryContainer: accentScheme.primaryContainer,
      onSecondaryContainer: accentScheme.onPrimaryContainer,

      tertiary: accentScheme.secondary,
      onTertiary: accentScheme.onSecondary,

      tertiaryContainer: accentScheme.secondaryContainer,
      onTertiaryContainer: accentScheme.onSecondaryContainer,
    );

    final strength = (backgroundStrength ?? 0.5).clamp(0.0, 1.0).toDouble();

    final background = brightness == Brightness.light
        ? lightBackground ??
              Color.alphaBlend(
                seedColor.withValues(alpha: 0.16 * strength),
                Colors.white,
              )
        : darkBackground ??
              Color.alphaBlend(
                seedColor.withValues(alpha: 0.20 * strength),
                const Color(0xFF121212),
              );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,

      badgeTheme: BadgeThemeData(
        backgroundColor: colorScheme.secondary,
        textColor: colorScheme.onSecondary,
      ),

      chipTheme: ChipThemeData(
        selectedColor: colorScheme.secondaryContainer,
        secondarySelectedColor: colorScheme.secondaryContainer,
      ),
    );
  }
}
