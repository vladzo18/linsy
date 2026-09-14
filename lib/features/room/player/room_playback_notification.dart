import 'dart:async';
import '../../../core/media/player_visibility.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/lifecycle/app_lifecycle_provider.dart';
import '../domain/models/playback_state.dart';
import '../presentation/controllers/playback_controller.dart';
import 'player_engine_provider.dart';
import 'room_pip.dart';

/// Serializes native updates so leaving a room cannot be overtaken by a late start.
class RoomPlaybackNotification {
  RoomPlaybackNotification(this.roomId, {MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('linsy/room_playback');
  final String roomId;
  final MethodChannel _channel;
  Future<void> _pending = Future.value();
  bool _disposed = false;

  void update(PlaybackState state, {bool locallyAllowed = true}) {
    if (_disposed) return;
    _pending = _pending
        .then((_) async {
          if (_disposed) return;
          if (state.trackId == null) {
            await _channel.invokeMethod<void>('stop', {'roomId': roomId});
          } else {
            await _channel.invokeMethod<void>('update', {
              'roomId': roomId,
              'title': state.title?.trim().isNotEmpty == true
                  ? state.title
                  : state.trackId,
              'playing': state.isPlaying && locallyAllowed,
              'positionMs': state.positionMs,
            });
          }
        })
        .catchError((Object error) {
          debugPrint('Room playback notification failed: $error');
        });
  }

  Future<void> dispose() {
    if (_disposed) return _pending;
    _disposed = true;
    _pending = _pending
        .then((_) => _channel.invokeMethod<void>('stop', {'roomId': roomId}))
        .catchError((Object error) {
          debugPrint('Could not stop room playback notification: $error');
        });
    return _pending;
  }
}

final roomPlaybackNotificationProvider = Provider.autoDispose
    .family<void, String>((ref, roomId) {
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
      final notification = RoomPlaybackNotification(roomId);
      final pip = ref.read(roomPipProvider.notifier);
      void refreshNotification() {
        final playback = ref.read(playbackControllerProvider(roomId)).value;
        if (playback != null) {
          notification.update(
            playback,
            locallyAllowed: playerVisibility.allowed,
          );
        }
      }

      playerVisibility.addListener(refreshNotification);
      ref.listen(playbackControllerProvider(roomId), (previous, next) {
        final playback = next.value;
        if (playback != null) {
          notification.update(
            playback,
            locallyAllowed: playerVisibility.allowed,
          );
        }
      }, fireImmediately: true);
      // Retry when returning to the app if Android rejected a background start.
      final lifecycle = ref.read(appLifecycleServiceProvider);
      // Observe only: these diagnostics must never restart or unmute playback.
      Timer? diagnosticTimer;
      void logPlayback(String reason) {
        if (!kDebugMode) return;
        final local = ref.read(playerEngineProvider).currentState;
        final remote = ref.read(playbackControllerProvider(roomId)).value;
        debugPrint(
          '[BackgroundPlayback] ${DateTime.now().toIso8601String()} '
          '$reason lifecycle=${lifecycle.state?.name} '
          'localPlaying=${local.isPlaying} localPosition=${local.positionMs} '
          'roomPlaying=${remote?.isPlaying} '
          'sameTrack=${local.trackId == remote?.trackId}',
        );
      }

      final subscription = lifecycle.states.listen((_) {
        if (kDebugMode) {
          diagnosticTimer?.cancel();
          logPlayback('lifecycle');
          if (!lifecycle.isForeground) {
            diagnosticTimer = Timer.periodic(const Duration(seconds: 2), (
              timer,
            ) {
              logPlayback('sample ${timer.tick}');
              if (timer.tick >= 15) timer.cancel();
            });
          }
        }
        if (!lifecycle.isForeground) return;
        final playback = ref.read(playbackControllerProvider(roomId)).value;
        if (playback != null) {
          notification.update(
            playback,
            locallyAllowed: playerVisibility.allowed,
          );
        }
      });
      ref.onDispose(() {
        playerVisibility.removeListener(refreshNotification);
        unawaited(pip.configure(false));
        diagnosticTimer?.cancel();
        if (kDebugMode) debugPrint('[BackgroundPlayback] session disposed');
        unawaited(subscription.cancel());
        unawaited(notification.dispose());
      });
    });
