import '../models/saved_track.dart';

abstract interface class SavedTracksRepository {
  Future<List<SavedTrack>> getSavedTracks(String userId);

  Future<SavedTrack> saveTrack({
    required String userId,
    required String source,
    required String trackId,
    required String title,
    required String channelTitle,
    String? thumbnailUrl,
    int? durationMs,
  });

  Future<void> removeTrack({
    required String userId,
    required String source,
    required String trackId,
  });
}
