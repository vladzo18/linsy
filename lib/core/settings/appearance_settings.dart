import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemePreset { linsy, lavender, rose, ocean, custom }

class AppearanceSettings {
  const AppearanceSettings({
    required this.preset,
    required this.themeMode,
    required this.customThemeName,
    required this.customSeedValue,
    required this.customAccentValue,
    required this.customBackgroundStrength,
  });

  final AppThemePreset preset;
  final ThemeMode themeMode;

  final String customThemeName;

  final int customSeedValue;
  final int customAccentValue;
  final double customBackgroundStrength;

  static const defaults = AppearanceSettings(
    preset: AppThemePreset.linsy,
    themeMode: ThemeMode.system,
    customThemeName: 'Custom',
    customSeedValue: 0xFF7655A6,
    customAccentValue: 0xFFE05D8A,
    customBackgroundStrength: 0.5,
  );

  Color get customSeedColor => Color(customSeedValue);

  Color get customAccentColor => Color(customAccentValue);

  AppearanceSettings copyWith({
    AppThemePreset? preset,
    ThemeMode? themeMode,
    String? customThemeName,
    int? customSeedValue,
    int? customAccentValue,
    double? customBackgroundStrength,
  }) {
    return AppearanceSettings(
      preset: preset ?? this.preset,
      themeMode: themeMode ?? this.themeMode,
      customThemeName: customThemeName ?? this.customThemeName,
      customSeedValue: customSeedValue ?? this.customSeedValue,
      customAccentValue: customAccentValue ?? this.customAccentValue,
      customBackgroundStrength:
          customBackgroundStrength ?? this.customBackgroundStrength,
    );
  }
}

final appearanceSettingsProvider =
    AsyncNotifierProvider<AppearanceSettingsController, AppearanceSettings>(
      AppearanceSettingsController.new,
    );

class AppearanceSettingsController extends AsyncNotifier<AppearanceSettings> {
  static const _presetKey = 'appearance_theme_preset';

  static const _modeKey = 'appearance_theme_mode';

  static const _customNameKey = 'appearance_custom_name';

  static const _customSeedKey = 'appearance_custom_seed';

  static const _customAccentKey = 'appearance_custom_accent';

  static const _customBackgroundStrengthKey =
      'appearance_custom_background_strength';

  @override
  Future<AppearanceSettings> build() async {
    final prefs = await SharedPreferences.getInstance();

    final presetName = prefs.getString(_presetKey);

    final modeName = prefs.getString(_modeKey);

    final preset =
        AppThemePreset.values
            .where((value) => value.name == presetName)
            .firstOrNull ??
        AppearanceSettings.defaults.preset;

    final mode =
        ThemeMode.values.where((value) => value.name == modeName).firstOrNull ??
        AppearanceSettings.defaults.themeMode;

    return AppearanceSettings(
      preset: preset,
      themeMode: mode,
      customThemeName: prefs.getString(_customNameKey) ?? 'Custom',
      customSeedValue:
          prefs.getInt(_customSeedKey) ??
          AppearanceSettings.defaults.customSeedValue,

      customAccentValue:
          prefs.getInt(_customAccentKey) ??
          AppearanceSettings.defaults.customAccentValue,

      customBackgroundStrength:
          (prefs.getDouble(_customBackgroundStrengthKey) ??
                  AppearanceSettings.defaults.customBackgroundStrength)
              .clamp(0.0, 1.0)
              .toDouble(),
    );
  }

  Future<void> setPreset(AppThemePreset preset) async {
    final current = state.value;

    if (current == null) {
      return;
    }

    state = AsyncData(current.copyWith(preset: preset));

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_presetKey, preset.name);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final current = state.value;

    if (current == null) {
      return;
    }

    state = AsyncData(current.copyWith(themeMode: mode));

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_modeKey, mode.name);
  }

  Future<void> saveCustomTheme({
    required String name,
    required Color seedColor,
    required Color accentColor,
    required double backgroundStrength,
  }) async {
    final current = state.value;

    if (current == null) {
      return;
    }

    final cleanedName = name.trim().isEmpty ? 'Custom' : name.trim();

    final normalizedBackground = backgroundStrength.clamp(0.0, 1.0).toDouble();

    final updated = current.copyWith(
      preset: AppThemePreset.custom,
      customThemeName: cleanedName,
      customSeedValue: seedColor.toARGB32(),
      customAccentValue: accentColor.toARGB32(),
      customBackgroundStrength: normalizedBackground,
    );

    state = AsyncData(updated);

    final prefs = await SharedPreferences.getInstance();

    await Future.wait([
      prefs.setString(_presetKey, AppThemePreset.custom.name),
      prefs.setString(_customNameKey, cleanedName),
      prefs.setInt(_customSeedKey, seedColor.toARGB32()),
      prefs.setInt(_customAccentKey, accentColor.toARGB32()),
      prefs.setDouble(_customBackgroundStrengthKey, normalizedBackground),
    ]);
  }
}
