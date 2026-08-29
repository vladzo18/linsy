import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/queue_repository_provider.dart';
import '../../domain/models/room_queue_item.dart';

final queueControllerProvider = AsyncNotifierProvider.autoDispose
    .family<QueueController, List<RoomQueueItem>, String>(QueueController.new);

class QueueController extends AsyncNotifier<List<RoomQueueItem>> {
  QueueController(this.roomId);

  final String roomId;

  StreamSubscription<List<RoomQueueItem>>? _subscription;

  @override
  Future<List<RoomQueueItem>> build() async {
    final repository = ref.read(queueRepositoryProvider);

    final completer = Completer<List<RoomQueueItem>>();

    _subscription = repository
        .watchQueue(roomId)
        .listen(
          (items) {
            state = AsyncData(items);

            if (!completer.isCompleted) {
              completer.complete(items);
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            state = AsyncError(error, stackTrace);

            if (!completer.isCompleted) {
              completer.completeError(error, stackTrace);
            }
          },
        );

    ref.onDispose(() {
      _subscription?.cancel();
    });

    return completer.future;
  }

  // ===================================================================
  // ADD
  // ===================================================================

  Future<void> addItem({
    required String trackId,
    String? title,
    String? thumbnailUrl,
    int? durationMs,
    String source = 'youtube',
  }) async {
    await ref
        .read(queueRepositoryProvider)
        .addItem(
          roomId: roomId,
          trackId: trackId,
          title: title,
          thumbnailUrl: thumbnailUrl,
          durationMs: durationMs,
          source: source,
        );

    // После собственного INSERT
    // не полагаемся только на realtime.
    //
    // Provider пересоздаст подписку,
    // а watchQueue сразу отдаст
    // актуальное состояние из БД.
    ref.invalidateSelf();
  }

  // ===================================================================
  // REMOVE
  // ===================================================================

  Future<void> removeItem(String itemId) async {
    final previousItems = state.value ?? const <RoomQueueItem>[];

    state = AsyncData(
      previousItems.where((item) => item.id != itemId).toList(),
    );

    try {
      await ref.read(queueRepositoryProvider).removeItem(itemId: itemId);
    } catch (error) {
      state = AsyncData(previousItems);

      rethrow;
    }
  }

  // ===================================================================
  // REORDER
  // ===================================================================

  Future<List<RoomQueueItem>> reorderItem({
    required String itemId,
    required int newIndex,
  }) {
    // Здесь state не меняем.
    //
    // UI очереди самостоятельно
    // держит optimistic порядок.
    return ref
        .read(queueRepositoryProvider)
        .reorderItem(roomId: roomId, itemId: itemId, newIndex: newIndex);
  }
}
