import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _defaultUiSoundVolume = 0.55;

class AppSoundSettings {
  const AppSoundSettings({required this.enabled, required this.volume});

  final bool enabled;
  final double volume;

  AppSoundSettings copyWith({bool? enabled, double? volume}) {
    return AppSoundSettings(
      enabled: enabled ?? this.enabled,
      volume: volume ?? this.volume,
    );
  }
}

final appSoundSettingsProvider =
    AsyncNotifierProvider<AppSoundSettingsController, AppSoundSettings>(
      AppSoundSettingsController.new,
    );

class AppSoundSettingsController extends AsyncNotifier<AppSoundSettings> {
  static const _enabledKey = 'ui_sounds_enabled';

  static const _volumeKey = 'ui_sounds_volume';

  @override
  Future<AppSoundSettings> build() async {
    final preferences = await SharedPreferences.getInstance();

    final enabled = preferences.getBool(_enabledKey) ?? true;

    final volume = (preferences.getDouble(_volumeKey) ?? _defaultUiSoundVolume)
        .clamp(0.0, 1.0)
        .toDouble();

    return AppSoundSettings(enabled: enabled, volume: volume);
  }

  // ===================================================================
  // ENABLED
  // ===================================================================

  Future<void> setEnabled(bool enabled) async {
    final current = state.value;

    if (current == null || current.enabled == enabled) {
      return;
    }

    final previous = current;

    state = AsyncData(current.copyWith(enabled: enabled));

    try {
      final preferences = await SharedPreferences.getInstance();

      await preferences.setBool(_enabledKey, enabled);
    } catch (error, stackTrace) {
      state = AsyncData(previous);

      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  // ===================================================================
  // VOLUME PREVIEW
  // ===================================================================

  void setVolume(double volume) {
    final current = state.value;

    if (current == null) {
      return;
    }

    final normalized = volume.clamp(0.0, 1.0).toDouble();

    state = AsyncData(current.copyWith(volume: normalized));
  }

  // ===================================================================
  // SAVE VOLUME
  // ===================================================================

  Future<void> saveVolume(double volume) async {
    final normalized = volume.clamp(0.0, 1.0).toDouble();

    setVolume(normalized);

    final preferences = await SharedPreferences.getInstance();

    await preferences.setDouble(_volumeKey, normalized);
  }
}
