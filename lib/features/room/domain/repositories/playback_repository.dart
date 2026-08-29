import '../models/playback_state.dart';

abstract interface class PlaybackRepository {
  Future<PlaybackState> getPlaybackState(String roomId);

  Future<void> updatePlaybackState({
    required String roomId,
    required String userId,
    String? trackId,
    required bool isPlaying,
    required int positionMs,
  });

  Stream<PlaybackState> watchPlaybackState(String roomId);

  Future<PlaybackState> playNext(String roomId);

  Future<PlaybackState> advanceIfEnded({
    required String roomId,
    required String expectedTrackId,
  });

  Future<PlaybackState?> play(String roomId);

  Future<PlaybackState?> pause(String roomId);

  Future<PlaybackState?> seek(String roomId, int positionMs);
}
