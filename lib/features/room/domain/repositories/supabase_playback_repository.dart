import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/playback_state.dart';
import '../../domain/repositories/playback_repository.dart';

class SupabasePlaybackRepository implements PlaybackRepository {
  final SupabaseClient _client;

  SupabasePlaybackRepository(this._client);

  @override
  Future<PlaybackState> getPlaybackState(String roomId) async {
    final response = await _client
        .from('room_playback')
        .select()
        .eq('room_id', roomId)
        .maybeSingle();

    if (response == null) {
      return PlaybackState.empty();
    }

    return _mapPlayback(response);
  }

  @override
  Future<void> updatePlaybackState({
    required String roomId,
    required String userId,
    String? trackId,
    required bool isPlaying,
    required int positionMs,
  }) async {
    await _client.rpc(
      'update_room_playback_state',
      params: {
        'p_room_id': roomId,
        'p_track_id': trackId,
        'p_is_playing': isPlaying,
        'p_position_ms': positionMs,
      },
    );
  }

  @override
  Stream<PlaybackState> watchPlaybackState(String roomId) {
    return _client
        .from('room_playback')
        .stream(primaryKey: const ['room_id'])
        .eq('room_id', roomId)
        .map((rows) {
          if (rows.isEmpty) {
            return PlaybackState.empty();
          }

          return _mapPlayback(rows.first);
        });
  }

  PlaybackState _mapPlayback(Map<String, dynamic> data) {
    return _mapPlaybackState(Map<String, dynamic>.from(data));
  }

  @override
  Future<PlaybackState> playNext(String roomId) async {
    final response = await _client.rpc(
      'play_next_room_track',
      params: {'p_room_id': roomId},
    );

    if (response is! Map) {
      throw StateError('Invalid response from play_next_room_track.');
    }

    return _mapPlaybackState(Map<String, dynamic>.from(response));
  }

  PlaybackState _mapPlaybackState(Map<String, dynamic> data) {
    return PlaybackState(
      trackId: data['track_id'] as String?,

      source: data['source'] as String?,

      title: data['title'] as String?,

      thumbnailUrl: data['thumbnail_url'] as String?,

      durationMs: (data['duration_ms'] as num?)?.toInt(),

      transitionKind: data['transition_kind'] as String?,

      addedBy: data['added_by'] as String?,

      isPlaying: data['is_playing'] as bool? ?? false,

      positionMs: (data['position_ms'] as num?)?.toInt() ?? 0,

      updatedAt: DateTime.parse(data['updated_at'] as String).toUtc(),

      scheduledStartAt: data['scheduled_start_at'] == null
          ? null
          : DateTime.parse(data['scheduled_start_at'] as String).toUtc(),

      updatedBy: data['updated_by'] as String?,
    );
  }

  @override
  Future<PlaybackState> advanceIfEnded({
    required String roomId,
    required String expectedTrackId,
  }) async {
    final response = await _client.rpc(
      'advance_room_track_if_ended',
      params: {'p_room_id': roomId, 'p_expected_track_id': expectedTrackId},
    );

    if (response is! Map) {
      throw StateError(
        'Invalid response from '
        'advance_room_track_if_ended.',
      );
    }

    return _mapPlaybackState(Map<String, dynamic>.from(response));
  }

  @override
  Future<PlaybackState?> play(String roomId) async {
    final data = await _client.rpc(
      'play_room_playback',
      params: {'p_room_id': roomId},
    );

    if (data == null) {
      return null;
    }

    return _mapPlaybackState(Map<String, dynamic>.from(data as Map));
  }

  @override
  Future<PlaybackState?> pause(String roomId) async {
    final data = await _client.rpc(
      'pause_room_playback',
      params: {'p_room_id': roomId},
    );

    if (data == null) {
      return null;
    }

    return _mapPlaybackState(Map<String, dynamic>.from(data as Map));
  }

  @override
  Future<PlaybackState?> seek(String roomId, int positionMs) async {
    final data = await _client.rpc(
      'seek_room_playback',
      params: {'p_room_id': roomId, 'p_position_ms': positionMs},
    );

    if (data == null) {
      return null;
    }

    return _mapPlaybackState(Map<String, dynamic>.from(data as Map));
  }
}
