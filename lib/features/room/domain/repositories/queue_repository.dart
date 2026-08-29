import '../models/room_queue_item.dart';

abstract interface class QueueRepository {
  Future<RoomQueueItem> addItem({
    required String roomId,
    required String trackId,
    String? title,
    String? thumbnailUrl,
    int? durationMs,
    String source = 'youtube',
  });

  Future<void> removeItem({required String itemId});

  Future<List<RoomQueueItem>> reorderItem({
    required String roomId,
    required String itemId,
    required int newIndex,
  });

  Stream<List<RoomQueueItem>> watchQueue(String roomId);
}
