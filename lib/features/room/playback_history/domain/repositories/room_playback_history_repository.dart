import '../models/room_playback_history_item.dart';

abstract class RoomPlaybackHistoryRepository {
  Stream<List<RoomPlaybackHistoryItem>> watchHistory(
    String roomId, {
    int limit = 50,
  });
}
