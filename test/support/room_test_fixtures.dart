import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:linsy/features/room/domain/models/playback_state.dart';
import 'package:linsy/features/room/domain/models/room_queue_item.dart';
import 'package:linsy/features/room/presentation/controllers/queue_controller.dart';
import 'package:linsy/features/room/presentation/controllers/playback_controller.dart';

class TestQueue extends QueueController {
  TestQueue() : super('room');
  String? moved;
  int? target;
  @override
  Future<List<RoomQueueItem>> build() async => List.generate(
    8,
    (i) => RoomQueueItem(
      id: '$i',
      roomId: 'room',
      source: 'youtube',
      trackId: '$i',
      title: 'Long track title number $i',
      thumbnailUrl: null,
      durationMs: 180000,
      position: i,
      addedBy: 'user',
      createdAt: DateTime(2026),
    ),
  );
  @override
  Future<List<RoomQueueItem>> reorderItem({
    required String itemId,
    required int newIndex,
  }) async {
    moved = itemId;
    target = newIndex;
    final items = [...state.requireValue];
    final old = items.indexWhere((item) => item.id == itemId);
    items.insert(newIndex, items.removeAt(old));
    state = AsyncData(items);
    return items;
  }
}

class TestPlayback extends PlaybackController {
  TestPlayback() : super('room');
  @override
  Future<PlaybackState> build() async => PlaybackState.empty();
}
