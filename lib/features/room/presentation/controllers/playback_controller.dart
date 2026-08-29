import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/playback_repository_provider.dart';
import '../../domain/models/playback_state.dart';
import '../../application/sync/room_consistency_coordinator_provider.dart';
import '../../application/sync/room_snapshot_sync.dart';

final playbackControllerProvider = AsyncNotifierProvider.autoDispose
    .family<PlaybackController, PlaybackState, String>(PlaybackController.new);

class PlaybackController extends AsyncNotifier<PlaybackState> {
  PlaybackController(this.roomId);

  final String roomId;

  StreamSubscription<PlaybackState>? _playbackSubscription;

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Future<PlaybackState> build() async {
    final repository = ref.read(playbackRepositoryProvider);

    final consistencyCoordinator = ref.watch(
      roomConsistencyCoordinatorProvider(roomId),
    );

    final playbackSync = RoomSnapshotSync<PlaybackState>(
      read: () => state.value,

      load: () => repository.getPlaybackState(roomId),

      write: (playback) {
        state = AsyncData(playback);
      },

      // Playback регулярно проверяем,
      // но не надо каждые 45 секунд дёргать
      // PlaybackSynchronizer тем же snapshot.
      shouldApply: (current, fetched) {
        return current.updatedAt != fetched.updatedAt ||
            current.trackId != fetched.trackId ||
            current.isPlaying != fetched.isPlaying ||
            current.positionMs != fetched.positionMs ||
            current.scheduledStartAt != fetched.scheduledStartAt;
      },
    );

    final unregisterSync = consistencyCoordinator.register(playbackSync);

    final initialState = await repository.getPlaybackState(roomId);

    _playbackSubscription = repository
        .watchPlaybackState(roomId)
        .listen(
          (playback) {
            state = AsyncData(playback);
          },
          onError: (Object error, StackTrace stackTrace) {
            state = AsyncError(error, stackTrace);
          },
        );

    ref.onDispose(() {
      unregisterSync();

      playbackSync.dispose();

      unawaited(_playbackSubscription?.cancel());

      _playbackSubscription = null;
    });

    return initialState;
  }

  // ============================================================
  // PLAY / PAUSE
  // ============================================================

  Future<void> setPlaying(bool isPlaying) async {
    final repository = ref.read(playbackRepositoryProvider);

    final PlaybackState? result;

    if (isPlaying) {
      result = await repository.play(roomId);
    } else {
      result = await repository.pause(roomId);
    }

    // Это не optimistic state.
    //
    // result уже пришёл от authoritative
    // server RPC.
    if (result != null) {
      state = AsyncData(result);
    }
  }

  // ============================================================
  // SEEK
  // ============================================================

  Future<void> seek(int positionMs) async {
    final repository = ref.read(playbackRepositoryProvider);

    final result = await repository.seek(roomId, positionMs);

    if (result != null) {
      state = AsyncData(result);
    }
  }

  // ============================================================
  // NEXT
  // ============================================================

  Future<void> next() async {
    final repository = ref.read(playbackRepositoryProvider);

    final playback = await repository.playNext(roomId);

    state = AsyncData(playback);
  }

  // ============================================================
  // AUTO NEXT
  // ============================================================

  Future<void> handleTrackEnded(String expectedTrackId) async {
    final repository = ref.read(playbackRepositoryProvider);

    final playback = await repository.advanceIfEnded(
      roomId: roomId,
      expectedTrackId: expectedTrackId,
    );

    state = AsyncData(playback);
  }
}
