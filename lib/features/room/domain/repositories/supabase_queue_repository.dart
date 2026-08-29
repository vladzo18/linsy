import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/room_queue_item.dart';
import '../../domain/repositories/queue_repository.dart';

class SupabaseQueueRepository implements QueueRepository {
  final SupabaseClient _client;

  SupabaseQueueRepository(this._client);

  @override
  Future<List<RoomQueueItem>> getQueue(String roomId) async {
    final rows = await _client
        .from('room_queue_items')
        .select()
        .eq('room_id', roomId)
        .order('position')
        .order('created_at')
        .order('id');

    return rows
        .map((row) => _mapQueueItem(Map<String, dynamic>.from(row)))
        .toList();
  }

  // ===================================================================
  // ADD
  // ===================================================================

  @override
  Future<RoomQueueItem> addItem({
    required String roomId,
    required String trackId,
    String? title,
    String? thumbnailUrl,
    int? durationMs,
    String source = 'youtube',
  }) async {
    final response = await _client.rpc(
      'add_room_queue_item',
      params: {
        'p_room_id': roomId,
        'p_track_id': trackId,
        'p_title': title,
        'p_thumbnail_url': thumbnailUrl,
        'p_duration_ms': durationMs,
        'p_source': source,
      },
    );

    if (response is! Map) {
      throw StateError(
        'Invalid response from '
        'add_room_queue_item.',
      );
    }

    return _mapQueueItem(Map<String, dynamic>.from(response));
  }

  // ===================================================================
  // REMOVE
  // ===================================================================

  @override
  Future<void> removeItem({required String itemId}) async {
    await _client.rpc('remove_room_queue_item', params: {'p_item_id': itemId});
  }

  // ===================================================================
  // REORDER
  // ===================================================================

  @override
  Future<List<RoomQueueItem>> reorderItem({
    required String roomId,
    required String itemId,
    required int newIndex,
  }) async {
    final response = await _client.rpc(
      'reorder_room_queue_item',
      params: {
        'p_room_id': roomId,
        'p_item_id': itemId,
        'p_new_index': newIndex,
      },
    );

    if (response is! List) {
      throw StateError(
        'Invalid response from '
        'reorder_room_queue_item.',
      );
    }

    final items = response.map((row) {
      if (row is! Map) {
        throw StateError(
          'Invalid queue item '
          'returned by '
          'reorder_room_queue_item.',
        );
      }

      return _mapQueueItem(Map<String, dynamic>.from(row));
    }).toList();

    // RPC и так возвращает sorted rows,
    // но на клиенте тоже фиксируем порядок.
    items.sort((a, b) => a.position.compareTo(b.position));

    return items;
  }

  // ===================================================================
  // WATCH
  // ===================================================================

  @override
  Stream<List<RoomQueueItem>> watchQueue(String roomId) {
    final controller = StreamController<List<RoomQueueItem>>();

    RealtimeChannel? channel;

    Timer? reloadTimer;

    var loading = false;
    var reloadRequested = false;
    var disposed = false;

    // ===================================================
    // LOAD
    // ===================================================

    Future<void> reloadQueue() async {
      if (disposed) {
        return;
      }

      // Если SELECT уже идёт —
      // просто запоминаем, что нужен ещё один.
      if (loading) {
        reloadRequested = true;
        return;
      }

      loading = true;

      try {
        do {
          reloadRequested = false;

          final items = await getQueue(roomId);

          if (disposed || controller.isClosed) {
            return;
          }

          controller.add(items);

          // Если пока выполнялся SELECT
          // пришло новое изменение —
          // сразу делаем ещё один SELECT.
        } while (reloadRequested);
      } catch (error, stackTrace) {
        if (!disposed && !controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      } finally {
        loading = false;
      }
    }

    // ===================================================
    // DEBOUNCE
    // ===================================================

    void scheduleReload() {
      reloadTimer?.cancel();

      reloadTimer = Timer(const Duration(milliseconds: 120), () {
        unawaited(reloadQueue());
      });
    }

    // ===================================================
    // REALTIME
    // ===================================================

    channel = _client
        .channel(
          'room-queue-'
          '$roomId-'
          '${DateTime.now().microsecondsSinceEpoch}',
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'room_queue_items',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (_) {
            scheduleReload();
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            // ВАЖНО:
            // сначала подписались,
            // только потом читаем snapshot.
            unawaited(reloadQueue());
          }

          if (status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.timedOut) {
            if (!controller.isClosed) {
              controller.addError(
                error ?? StateError('Queue realtime connection failed.'),
              );
            }
          }
        });

    // ===================================================
    // DISPOSE
    // ===================================================

    controller.onCancel = () async {
      disposed = true;

      reloadTimer?.cancel();
      reloadTimer = null;

      final currentChannel = channel;

      if (currentChannel != null) {
        await _client.removeChannel(currentChannel);
      }

      await controller.close();
    };

    return controller.stream;
  }

  // ===================================================================
  // MAP
  // ===================================================================

  RoomQueueItem _mapQueueItem(Map<String, dynamic> data) {
    return RoomQueueItem(
      id: data['id'] as String,
      roomId: data['room_id'] as String,
      source: data['source'] as String,
      trackId: data['track_id'] as String,
      title: data['title'] as String?,
      thumbnailUrl: data['thumbnail_url'] as String?,
      durationMs: (data['duration_ms'] as num?)?.toInt(),
      position: (data['position'] as num).toInt(),
      addedBy: data['added_by'] as String,
      createdAt: DateTime.parse(data['created_at'] as String),
    );
  }
}
