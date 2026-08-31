import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/room_playback_history_item.dart';
import '../../domain/repositories/room_playback_history_repository.dart';

class SupabaseRoomPlaybackHistoryRepository
    implements RoomPlaybackHistoryRepository {
  SupabaseRoomPlaybackHistoryRepository(this._client);

  final SupabaseClient _client;

  @override
  Stream<List<RoomPlaybackHistoryItem>> watchHistory(
    String roomId, {
    int limit = 50,
  }) {
    final safeLimit = limit.clamp(1, 100);

    return _client
        .from('room_playback_history')
        .stream(primaryKey: const ['id'])
        .eq('room_id', roomId)
        .order('played_at', ascending: false)
        .limit(safeLimit)
        .map((rows) {
          return rows
              .map(RoomPlaybackHistoryItem.fromMap)
              .toList(growable: false);
        });
  }
}
