import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/playback_repository_provider.dart';
import '../../domain/models/playback_state.dart';

final playbackControllerProvider =
    AsyncNotifierProvider.family<PlaybackController, PlaybackState, String>(
      PlaybackController.new,
    );

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
      _playbackSubscription?.cancel();
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
