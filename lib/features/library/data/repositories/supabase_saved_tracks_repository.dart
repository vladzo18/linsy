import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/saved_track.dart';
import '../../domain/repositories/saved_tracks_repository.dart';

class SupabaseSavedTracksRepository implements SavedTracksRepository {
  SupabaseSavedTracksRepository(this._client);

  final SupabaseClient _client;

  // ===================================================
  // GET
  // ===================================================

  @override
  Future<List<SavedTrack>> getSavedTracks(String userId) async {
    final rows = await _client
        .from('saved_tracks')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return rows
        .map((row) => _mapTrack(Map<String, dynamic>.from(row)))
        .toList();
  }

  // ===================================================
  // SAVE
  // ===================================================

  @override
  Future<SavedTrack> saveTrack({
    required String userId,
    required String source,
    required String trackId,
    required String title,
    required String channelTitle,
    String? thumbnailUrl,
    int? durationMs,
  }) async {
    final normalizedSource = source.trim();

    final normalizedTrackId = trackId.trim();

    final normalizedTitle = title.trim();

    final normalizedChannelTitle = channelTitle.trim();

    if (normalizedSource.isEmpty) {
      throw ArgumentError('Track source cannot be empty.');
    }

    if (normalizedTrackId.isEmpty) {
      throw ArgumentError('Track ID cannot be empty.');
    }

    if (normalizedTitle.isEmpty) {
      throw ArgumentError('Track title cannot be empty.');
    }

    final row = await _client
        .from('saved_tracks')
        .insert({
          'user_id': userId,
          'source': normalizedSource,
          'track_id': normalizedTrackId,
          'title': normalizedTitle,
          'channel_title': normalizedChannelTitle,
          'thumbnail_url': thumbnailUrl,
          'duration_ms': durationMs,
        })
        .select()
        .single();

    return _mapTrack(Map<String, dynamic>.from(row));
  }

  // ===================================================
  // REMOVE
  // ===================================================

  @override
  Future<void> removeTrack({
    required String userId,
    required String source,
    required String trackId,
  }) async {
    await _client
        .from('saved_tracks')
        .delete()
        .eq('user_id', userId)
        .eq('source', source)
        .eq('track_id', trackId);
  }

  // ===================================================
  // MAP
  // ===================================================

  SavedTrack _mapTrack(Map<String, dynamic> data) {
    final rawDuration = data['duration_ms'];

    final rawCreatedAt = data['created_at'];

    return SavedTrack(
      id: data['id'] as String,

      userId: data['user_id'] as String,

      source: data['source'] as String,

      trackId: data['track_id'] as String,

      title: data['title'] as String,

      channelTitle: data['channel_title'] as String? ?? '',

      thumbnailUrl: data['thumbnail_url'] as String?,

      durationMs: rawDuration is num ? rawDuration.toInt() : null,

      createdAt: rawCreatedAt is String
          ? DateTime.parse(rawCreatedAt).toUtc()
          : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}
