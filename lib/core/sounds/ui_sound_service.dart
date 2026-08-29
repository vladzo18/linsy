import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'ui_sound.dart';

class UiSoundService {
  final Map<
    UiSound,
    Future<AudioPool>
  >
  _pools = {};

  bool _enabled = true;

  double _volume = 0.55;

  bool _disposed = false;

  bool get enabled => _enabled;

  double get volume => _volume;

  // ===================================================================
  // SETTINGS
  // ===================================================================

  void setEnabled(
    bool enabled,
  ) {
    _enabled = enabled;
  }

  void setVolume(
    double volume,
  ) {
    _volume = volume
        .clamp(
          0.0,
          1.0,
        )
        .toDouble();
  }

  // ===================================================================
  // PLAY
  // ===================================================================

  Future<void> play(
    UiSound sound, {
    double? volume,
  }) async {
    if (_disposed ||
        !_enabled) {
      return;
    }

    try {
      final pool =
          await _getPool(
        sound,
      );

      if (_disposed) {
        return;
      }

      final effectiveVolume =
          (volume ?? _volume)
              .clamp(
                0.0,
                1.0,
              )
              .toDouble();

      await pool.start(
        volume:
            effectiveVolume,
      );
    } catch (
      error,
      stackTrace
    ) {
      // UI sound никогда не должен ломать приложение.
      debugPrint(
        'Failed to play UI sound '
        '${sound.name}: $error',
      );

      debugPrintStack(
        stackTrace:
            stackTrace,
      );
    }
  }

  // ===================================================================
  // POOL
  // ===================================================================

  Future<AudioPool> _getPool(
    UiSound sound,
  ) {
    return _pools.putIfAbsent(
      sound,
      () {
        return AudioPool.createFromAsset(
          path:
              sound.assetPath,

          // Несколько быстрых сообщений подряд
          // могут звучать одновременно.
          maxPlayers:
              3,

          // Один player готов заранее.
          minPlayers:
              1,
        );
      },
    );
  }

  // ===================================================================
  // DISPOSE
  // ===================================================================

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    _disposed = true;

    final pools =
        _pools.values.toList();

    _pools.clear();

    for (final futurePool
        in pools) {
      try {
        final pool =
            await futurePool;

        await pool.dispose();
      } catch (_) {
        // Ничего страшного:
        // service уже уничтожается.
      }
    }
  }
}