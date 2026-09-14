import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/media/player_visibility.dart';
import 'player_engine.dart';

/// Serializes local player commands and rejects starts while the embed is hidden.
/// It never changes the shared room playback state.
class VisiblePlayerEngine implements PlayerEngine {
  VisiblePlayerEngine(this.inner, this.visibility) {
    visibility.addListener(_visibilityChanged);
    _visibilityChanged();
  }
  final PlayerEngine inner;
  final PlayerVisibility visibility;
  Future<void> _pending = Future.value();
  bool _disposed = false;

  Future<void> _enqueue(
    Future<void> Function() action, {
    bool needsVideo = false,
  }) {
    final operation = _pending.then((_) async {
      if (_disposed || (needsVideo && !visibility.allowed)) return;
      await action();
      if (!_disposed && needsVideo && !visibility.allowed) await inner.pause();
    });
    _pending = operation.catchError((Object error) {
      debugPrint('[VisiblePlayer] Command failed: $error');
    });
    return operation;
  }

  void _visibilityChanged() {
    if (!visibility.allowed) unawaited(pause().catchError((Object _) {}));
  }

  @override
  PlayerEngineState get currentState => inner.currentState;
  @override
  Stream<String> get endedTrackIds =>
      inner.endedTrackIds.where((_) => visibility.allowed);
  @override
  Future<void> load(String id, {int startPositionMs = 0}) => _enqueue(
    () => inner.load(id, startPositionMs: startPositionMs),
    needsVideo: true,
  );
  @override
  Future<void> play() => _enqueue(inner.play, needsVideo: true);
  @override
  Future<void> seek(int positionMs) =>
      _enqueue(() => inner.seek(positionMs), needsVideo: true);
  @override
  Future<void> pause() => _enqueue(inner.pause);
  @override
  Future<void> stop() => _enqueue(inner.stop);
  @override
  Future<void> setVolume(double volume) =>
      _enqueue(() => inner.setVolume(volume));
  @override
  void dispose() {
    _disposed = true;
    visibility.removeListener(_visibilityChanged);
    // The platform provider owns the underlying player.
  }
}
