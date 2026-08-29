import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlaybackSettings {
  const PlaybackSettings({required this.defaultVolume});

  final double defaultVolume;

  static const defaults = PlaybackSettings(defaultVolume: 0.45);

  PlaybackSettings copyWith({double? defaultVolume}) {
    return PlaybackSettings(defaultVolume: defaultVolume ?? this.defaultVolume);
  }
}

final playbackSettingsProvider =
    AsyncNotifierProvider<PlaybackSettingsController, PlaybackSettings>(
      PlaybackSettingsController.new,
    );

class PlaybackSettingsController extends AsyncNotifier<PlaybackSettings> {
  static const _defaultVolumeKey = 'player_default_volume';

  double _persistedVolume = PlaybackSettings.defaults.defaultVolume;

  @override
  Future<PlaybackSettings> build() async {
    final preferences = await SharedPreferences.getInstance();

    final volume =
        (preferences.getDouble(_defaultVolumeKey) ??
                PlaybackSettings.defaults.defaultVolume)
            .clamp(0.0, 1.0)
            .toDouble();

    _persistedVolume = volume;

    return PlaybackSettings(defaultVolume: volume);
  }

  // ===================================================================
  // LOCAL SLIDER UPDATE
  // ===================================================================

  void setDefaultVolume(double volume) {
    final current = state.value;

    if (current == null) {
      return;
    }

    final normalized = volume.clamp(0.0, 1.0).toDouble();

    state = AsyncData(current.copyWith(defaultVolume: normalized));
  }

  // ===================================================================
  // SAVE
  // ===================================================================

  Future<void> saveDefaultVolume(double volume) async {
    final current = state.value;

    if (current == null) {
      return;
    }

    final normalized = volume.clamp(0.0, 1.0).toDouble();

    setDefaultVolume(normalized);

    try {
      final preferences = await SharedPreferences.getInstance();

      await preferences.setDouble(_defaultVolumeKey, normalized);

      _persistedVolume = normalized;
    } catch (error, stackTrace) {
      state = AsyncData(current.copyWith(defaultVolume: _persistedVolume));

      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
