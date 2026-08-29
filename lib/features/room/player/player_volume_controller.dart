import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/playback_settings.dart';
import 'player_engine_provider.dart';

final playerVolumeProvider = NotifierProvider<PlayerVolumeController, double>(
  PlayerVolumeController.new,
);

class PlayerVolumeController extends Notifier<double> {
  bool _defaultVolumeApplied = false;

  bool _changedByUser = false;

  @override
  double build() {
    // ===============================================================
    // DEFAULT VOLUME
    //
    // PlaybackSettings загружается асинхронно.
    // Когда значение станет доступно, применяем его ОДИН раз.
    // ===============================================================

    ref.listen(playbackSettingsProvider, (previous, next) {
      final settings = next.value;

      if (settings == null || _defaultVolumeApplied || _changedByUser) {
        return;
      }

      _defaultVolumeApplied = true;

      final defaultVolume = settings.defaultVolume;

      unawaited(
        Future.microtask(() async {
          // Пользователь мог успеть изменить громкость,
          // пока настройки загружались.
          if (_changedByUser) {
            return;
          }

          final previousVolume = state;

          state = defaultVolume;

          try {
            await ref.read(playerEngineProvider).setVolume(defaultVolume);
          } catch (_) {
            state = previousVolume;
          }
        }),
      );
    }, fireImmediately: true);

    // Пока SharedPreferences загружается,
    // сохраняем старое поведение.
    return 1.0;
  }

  // ===================================================================
  // CURRENT LOCAL VOLUME
  // ===================================================================

  Future<void> setVolume(double volume) async {
    final normalized = volume.clamp(0.0, 1.0).toDouble();

    // После ручного изменения default volume
    // уже не имеет права вмешиваться в текущую сессию.
    _changedByUser = true;

    final previous = state;

    state = normalized;

    try {
      await ref.read(playerEngineProvider).setVolume(normalized);
    } catch (_) {
      state = previous;

      rethrow;
    }
  }
}
