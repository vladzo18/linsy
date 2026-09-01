import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/server_clock.dart';
import '../domain/models/playback_state.dart';
import '../presentation/controllers/playback_controller.dart';
import 'player_engine.dart';
import 'player_engine_provider.dart';

const int _driftThresholdMs = 1800;

const Duration _driftCheckInterval = Duration(seconds: 5);

const Duration _afterLoadGracePeriod = Duration(seconds: 8);

const Duration _correctionCooldown = Duration(seconds: 10);

// =====================================================
// PLAYBACK SYNCHRONIZER
// =====================================================

class PlaybackSynchronizer {
  final PlayerEngine _engine;
  final ServerClock _serverClock;

  PlaybackState? _latestRemoteState;

  Timer? _driftTimer;
  Timer? _scheduledPlayTimer;

  Future<void> _operationQueue = Future.value();

  DateTime? _trackLoadedAt;

  DateTime? _lastDriftCorrection;

  String? _preparedTrackId;

  DateTime? _preparedStartAt;

  int? _preparedPositionMs;

  PlaybackSynchronizer(this._engine, this._serverClock);

  // ===================================================
  // START
  // ===================================================

  void start() {
    _driftTimer = Timer.periodic(_driftCheckInterval, (_) {
      final remote = _latestRemoteState;

      if (remote == null || !remote.isPlaying) {
        return;
      }

      final scheduled = remote.scheduledStartAt;

      if (scheduled != null && _serverClock.now().isBefore(scheduled)) {
        return;
      }

      _enqueue(remote);
    });
  }

  // ===================================================
  // UPDATE
  // ===================================================

  void update(PlaybackState remote) {
    _latestRemoteState = remote;

    _enqueue(remote);
  }

  // ===================================================
  // QUEUE
  // ===================================================

  void _enqueue(PlaybackState remote) {
    _operationQueue = _operationQueue
        .then((_) => _synchronize(remote))
        .catchError((Object error, StackTrace stackTrace) {
          debugPrint(
            '[PlaybackSynchronizer] '
            '$error',
          );

          debugPrintStack(stackTrace: stackTrace);
        });
  }

  // ===================================================
  // SYNC
  // ===================================================

  Future<void> _synchronize(PlaybackState remote) async {
    final remoteTrackId = remote.trackId;

    if (remoteTrackId == null) {
      _cancelScheduledPlay();

      if (_engine.currentState.trackId != null) {
        await _engine.stop();
      }

      _resetPreparedState();

      return;
    }

    final serverNow = _serverClock.now();

    final scheduledStartAt = remote.scheduledStartAt;

    final waitingForStart =
        remote.isPlaying &&
        scheduledStartAt != null &&
        serverNow.isBefore(scheduledStartAt);

    // -------------------------------------------------
    // SCHEDULED START
    // -------------------------------------------------

    if (waitingForStart) {
      await _prepareScheduledStart(remote, scheduledStartAt);

      return;
    }

    // scheduled start уже наступил
    // или это legacy playback state.
    _cancelScheduledPlay();

    final targetPosition = remote.positionAt(serverNow);

    final local = _engine.currentState;

    // -------------------------------------------------
    // DIFFERENT TRACK
    // -------------------------------------------------

    if (local.trackId != remoteTrackId) {
      debugPrint(
        '[Sync] Late load: '
        '${local.trackId} '
        '→ $remoteTrackId '
        '@ $targetPosition ms',
      );

      await _engine.load(remoteTrackId, startPositionMs: targetPosition);

      _trackLoadedAt = DateTime.now().toUtc();
    }

    // -------------------------------------------------
    // PAUSED
    // -------------------------------------------------

    if (!remote.isPlaying) {
      if (_engine.currentState.isPlaying) {
        await _engine.pause();
      }

      final currentPosition = _engine.currentState.positionMs;

      final pausedDrift = currentPosition - remote.positionMs;

      if (pausedDrift.abs() > 300) {
        await _engine.seek(remote.positionMs);
      }

      return;
    }

    // -------------------------------------------------
    // PLAYING
    // -------------------------------------------------

    final current = _engine.currentState;

    final localPosition = current.positionMs;

    final drift = localPosition - targetPosition;

    final checkpointAnchor = remote.scheduledStartAt ?? remote.updatedAt;

    final checkpointAge = serverNow
        .difference(checkpointAnchor.toUtc())
        .inMilliseconds;

    debugPrint(
      '[Sync] '
      'remote=$targetPosition ms | '
      'local=$localPosition ms | '
      'drift=${drift >= 0 ? '+' : ''}$drift ms | '
      'checkpointAge=$checkpointAge ms',
    );

    final localNow = DateTime.now().toUtc();

    final justLoaded =
        _trackLoadedAt != null &&
        localNow.difference(_trackLoadedAt!) < _afterLoadGracePeriod;

    final correctionOnCooldown =
        _lastDriftCorrection != null &&
        localNow.difference(_lastDriftCorrection!) < _correctionCooldown;

    if (!justLoaded &&
        !correctionOnCooldown &&
        drift.abs() > _driftThresholdMs) {
      final correctedPosition = remote.positionAt(_serverClock.now());

      debugPrint(
        '[Sync] '
        'Correcting drift '
        '${drift.abs()} ms '
        '→ $correctedPosition ms',
      );

      await _engine.seek(correctedPosition);

      _lastDriftCorrection = DateTime.now().toUtc();
    }

    if (!_engine.currentState.isPlaying) {
      await _engine.play();
    }
  }

  // ===================================================
  // PREPARE SCHEDULED START
  // ===================================================

  Future<void> _prepareScheduledStart(
    PlaybackState remote,
    DateTime scheduledStartAt,
  ) async {
    final trackId = remote.trackId!;

    final scheduledUtc = scheduledStartAt.toUtc();

    final alreadyPrepared =
        _preparedTrackId == trackId &&
        _preparedStartAt == scheduledUtc &&
        _preparedPositionMs == remote.positionMs;

    if (!alreadyPrepared) {
      debugPrint(
        '[Sync] Preparing '
        '$trackId '
        '@ ${remote.positionMs} ms',
      );

      final local = _engine.currentState;

      if (local.trackId != trackId) {
        // IMPORTANT:
        //
        // loadVideoById запускает новый ролик muted.
        // YoutubePlayerEngine сам дождётся
        // PlayerState.playing и только после этого
        // выполнит _pauseAfterAutoplay().
        //
        // Поэтому здесь НЕ вызываем pause()
        // сразу после load().
        await _engine.load(trackId, startPositionMs: remote.positionMs);

        _trackLoadedAt = DateTime.now().toUtc();

        debugPrint(
          '[Sync] Waiting for player '
          'preload...',
        );
      } else {
        // Трек уже загружен.
        //
        // Например обычный Pause → Play.
        if (local.isPlaying) {
          await _engine.pause();
        }

        final pausedLocal = _engine.currentState;

        final preparationDrift = pausedLocal.positionMs - remote.positionMs;

        if (preparationDrift.abs() > 500) {
          debugPrint(
            '[Sync] Preparing seek | '
            'drift=$preparationDrift ms',
          );

          await _engine.seek(remote.positionMs);

          await _engine.pause();
        } else {
          debugPrint(
            '[Sync] Preparing without seek | '
            'drift=$preparationDrift ms',
          );
        }
      }

      _preparedTrackId = trackId;

      _preparedStartAt = scheduledUtc;

      _preparedPositionMs = remote.positionMs;
    }

    _schedulePlay(trackId, scheduledUtc);
  }

  // ===================================================
  // SCHEDULE PLAY
  // ===================================================

  void _schedulePlay(String trackId, DateTime scheduledStartAt) {
    final existing = _scheduledPlayTimer;

    if (existing != null &&
        existing.isActive &&
        _preparedTrackId == trackId &&
        _preparedStartAt == scheduledStartAt) {
      return;
    }

    _scheduledPlayTimer?.cancel();

    var delay = scheduledStartAt.difference(_serverClock.now());

    if (delay.isNegative) {
      delay = Duration.zero;
    }

    debugPrint(
      '[Sync] Scheduled PLAY '
      'in ${delay.inMilliseconds} ms',
    );

    _scheduledPlayTimer = Timer(delay, () {
      _operationQueue = _operationQueue
          .then((_) => _fireScheduledPlay(trackId, scheduledStartAt))
          .catchError((Object error, StackTrace stackTrace) {
            debugPrint(
              '[Sync] '
              'Scheduled PLAY failed: '
              '$error',
            );

            debugPrintStack(stackTrace: stackTrace);
          });
    });
  }

  // ===================================================
  // FIRE SCHEDULED PLAY
  // ===================================================

  Future<void> _fireScheduledPlay(
    String trackId,
    DateTime scheduledStartAt,
  ) async {
    _scheduledPlayTimer = null;

    final remote = _latestRemoteState;

    if (remote == null) {
      return;
    }

    if (!remote.isPlaying ||
        remote.trackId != trackId ||
        remote.scheduledStartAt?.toUtc() != scheduledStartAt) {
      debugPrint(
        '[Sync] '
        'Scheduled PLAY cancelled',
      );

      return;
    }

    final now = _serverClock.now();

    final lateBy = now.difference(scheduledStartAt).inMilliseconds;

    // ===================================================
    // AUTHORITATIVE START POSITION
    // ===================================================
    //
    // Даже если YouTube успел проиграть часть muted preload,
    // именно сервер решает, где трек должен находиться
    // в момент scheduledStartAt.
    // ===================================================

    final targetPosition = remote.positionAt(now);

    // ===================================================
    // LATE LOAD
    // ===================================================

    if (_engine.currentState.trackId != trackId) {
      debugPrint(
        '[Sync] '
        'Scheduled start requires late load '
        '@ $targetPosition ms',
      );

      await _engine.load(trackId, startPositionMs: targetPosition);

      _trackLoadedAt = DateTime.now().toUtc();
    }

    // ===================================================
    // FINAL START ALIGNMENT
    // ===================================================

    final localBeforeStart = _engine.currentState;

    final startDrift = localBeforeStart.positionMs - targetPosition;

    debugPrint(
      '[Sync] PLAY NOW | '
      'lateBy=$lateBy ms | '
      'target=$targetPosition ms | '
      'local=${localBeforeStart.positionMs} ms | '
      'startDrift='
      '${startDrift >= 0 ? '+' : ''}'
      '$startDrift ms',
    );

    // Во время preload один backend может успеть
    // проиграть несколько секунд.
    //
    // Перед PLAY возвращаем его точно к серверной
    // позиции.
    if (startDrift.abs() > 250) {
      debugPrint(
        '[Sync] '
        'Aligning scheduled start '
        '${localBeforeStart.positionMs} '
        '→ $targetPosition ms',
      );

      await _engine.seek(targetPosition);
    }

    // Только после выравнивания разрешаем звук
    // и реальное воспроизведение.
    await _engine.play();
  }

  // ===================================================
  // HELPERS
  // ===================================================

  void _cancelScheduledPlay() {
    _scheduledPlayTimer?.cancel();

    _scheduledPlayTimer = null;
  }

  void _resetPreparedState() {
    _preparedTrackId = null;
    _preparedStartAt = null;
    _preparedPositionMs = null;

    _trackLoadedAt = null;
    _lastDriftCorrection = null;
  }

  // ===================================================
  // DISPOSE
  // ===================================================

  void dispose() {
    _driftTimer?.cancel();

    _cancelScheduledPlay();

    _driftTimer = null;

    _latestRemoteState = null;

    _resetPreparedState();
  }
}

// =====================================================
// PROVIDER
// =====================================================

final playbackSynchronizerProvider = Provider.autoDispose.family<void, String>((
  ref,
  roomId,
) {
  final clockState = ref.watch(serverClockProvider);

  final serverClock = clockState.value;

  if (serverClock == null) {
    return;
  }

  final engine = ref.watch(playerEngineProvider);

  final synchronizer = PlaybackSynchronizer(engine, serverClock);

  synchronizer.start();

  ref.listen(playbackControllerProvider(roomId), (previous, next) {
    final playback = next.value;

    if (playback == null) {
      return;
    }

    synchronizer.update(playback);
  }, fireImmediately: true);

  final endedSubscription = engine.endedTrackIds.listen((trackId) async {
    debugPrint(
      '[PlaybackSynchronizer] '
      'Track ended: $trackId',
    );

    try {
      await ref
          .read(playbackControllerProvider(roomId).notifier)
          .handleTrackEnded(trackId);
    } catch (error, stackTrace) {
      debugPrint(
        '[PlaybackSynchronizer] '
        'Auto-next failed: '
        '$error',
      );

      debugPrintStack(stackTrace: stackTrace);
    }
  });

  ref.onDispose(() {
    unawaited(endedSubscription.cancel());

    synchronizer.dispose();
  });
});
