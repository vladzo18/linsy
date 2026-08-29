import 'dart:async';

class PlayerEngineState {
  final String? trackId;
  final bool isPlaying;
  final int positionMs;

  const PlayerEngineState({
    required this.trackId,
    required this.isPlaying,
    required this.positionMs,
  });
}

abstract class PlayerEngine {
  PlayerEngineState get currentState;

  Stream<String> get endedTrackIds;

  Future<void> load(String trackId, {int startPositionMs = 0});

  Future<void> play();

  Future<void> pause();

  Future<void> seek(int positionMs);

  Future<void> setVolume(double volume);

  Future<void> stop();

  void dispose();
}

// =====================================================
// MOCK PLAYER ENGINE
// =====================================================

class MockPlayerEngine implements PlayerEngine {
  String? _trackId;

  bool _isPlaying = false;

  int _checkpointPositionMs = 0;

  DateTime? _startedAt;

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Stream<String> get endedTrackIds => const Stream<String>.empty();

  @override
  PlayerEngineState get currentState {
    return PlayerEngineState(
      trackId: _trackId,
      isPlaying: _isPlaying,
      positionMs: _currentPosition(),
    );
  }

  int _currentPosition() {
    if (!_isPlaying || _startedAt == null) {
      return _checkpointPositionMs;
    }

    final elapsed = DateTime.now().difference(_startedAt!).inMilliseconds;

    return _checkpointPositionMs + elapsed;
  }

  @override
  Future<void> load(String trackId, {int startPositionMs = 0}) async {
    _trackId = trackId;

    _checkpointPositionMs = startPositionMs;

    _isPlaying = false;
    _startedAt = null;
  }

  @override
  Future<void> play() async {
    if (_trackId == null || _isPlaying) {
      return;
    }

    _checkpointPositionMs = _currentPosition();

    _startedAt = DateTime.now();

    _isPlaying = true;
  }

  @override
  Future<void> pause() async {
    if (!_isPlaying) {
      return;
    }

    _checkpointPositionMs = _currentPosition();

    _startedAt = null;
    _isPlaying = false;
  }

  @override
  Future<void> seek(int positionMs) async {
    _checkpointPositionMs = positionMs < 0 ? 0 : positionMs;

    if (_isPlaying) {
      _startedAt = DateTime.now();
    }
  }

  @override
  Future<void> stop() async {
    _trackId = null;

    _checkpointPositionMs = 0;

    _startedAt = null;

    _isPlaying = false;
  }

  @override
  void dispose() {}
}
