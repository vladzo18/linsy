import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/room_queue_item.dart';
import '../../domain/repositories/queue_repository.dart';

class SupabaseQueueRepository implements QueueRepository {
  SupabaseQueueRepository(this._client);

  final SupabaseClient _client;

  // ===================================================
  // GET
  // ===================================================

 @override
Future<List<RoomQueueItem>> getQueue(
  String roomId,
) async {
  final rows = await _client
      .from('room_queue_items')
      .select()
      .eq('room_id', roomId)
      .order(
        'position',
        ascending: true,
      )
      .order(
        'created_at',
        ascending: true,
      )
      .order(
        'id',
        ascending: true,
      );

  final items = rows
      .map(
        (row) => _mapQueueItem(
          Map<String, dynamic>.from(row),
        ),
      )
      .toList();

  return items;
}
  // ===================================================
  // ADD
  // ===================================================

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

  // ===================================================
  // REMOVE
  // ===================================================

  @override
  Future<void> removeItem({required String itemId}) async {
    await _client.rpc('remove_room_queue_item', params: {'p_item_id': itemId});
  }

  // ===================================================
  // REORDER
  // ===================================================

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
          'Invalid queue item returned by '
          'reorder_room_queue_item.',
        );
      }

      return _mapQueueItem(Map<String, dynamic>.from(row));
    }).toList();

    // Сервер уже возвращает ordered result,
    // но клиент также делает deterministic sort.
    items.sort(_compareQueueItems);

    return items;
  }

  // ===================================================
  // WATCH
  // ===================================================

  @override
  Stream<List<RoomQueueItem>> watchQueue(String roomId) {
    // sync:true нужен, чтобы между controller.add()
    // и QueueController listener не оставалось
    // дополнительного асинхронного окна.
    final controller = StreamController<List<RoomQueueItem>>(sync: true);

    RealtimeChannel? channel;

    Timer? reloadTimer;
    Timer? initialFallbackTimer;

    var disposed = false;

    var loading = false;

    // Если event приходит, пока SELECT уже выполняется,
    // после него обязательно выполняем ещё один SELECT.
    var reloadRequested = false;

    var initialLoadStarted = false;

    // =================================================
    // LOAD SNAPSHOT
    // =================================================

    Future<void> reloadQueue() async {
      if (disposed) {
        return;
      }

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

          // Очень важный момент:
          //
          // если пока SELECT выполнялся
          // пришёл Realtime event,
          // НЕ публикуем потенциально старый
          // snapshot.
          //
          // Сразу делаем следующий SELECT.
          if (reloadRequested) {
            continue;
          }

          controller.add(items);
        } while (reloadRequested);
      } catch (error, stackTrace) {
        if (!disposed && !controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      } finally {
        loading = false;

        // На случай если request пришёл
        // прямо на границе завершения цикла.
        if (reloadRequested && !disposed) {
          reloadRequested = false;

          unawaited(reloadQueue());
        }
      }
    }

    // =================================================
    // REALTIME CHANGE
    // =================================================

    void scheduleReload() {
      if (disposed) {
        return;
      }

      reloadTimer?.cancel();

      // Reorder обновляет сразу несколько rows.
      // Объединяем пачку UPDATE events
      // в один SELECT.
      reloadTimer = Timer(const Duration(milliseconds: 120), () {
        unawaited(reloadQueue());
      });
    }

    // =================================================
    // INITIAL SNAPSHOT
    // =================================================

    void startInitialLoad() {
      if (disposed || initialLoadStarted) {
        return;
      }

      initialLoadStarted = true;

      unawaited(reloadQueue());
    }

    // =================================================
    // SUBSCRIBE FIRST
    // =================================================

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
          if (disposed) {
            return;
          }

          if (status == RealtimeSubscribeStatus.subscribed) {
            initialFallbackTimer?.cancel();

            initialFallbackTimer = null;

            // Только после SUBSCRIBED
            // берём initial DB snapshot.
            startInitialLoad();
          }
        });

    // Если Realtime сейчас временно лежит,
    // не оставляем UI бесконечно loading.
    //
    // REST snapshot всё равно можно получить.
    initialFallbackTimer = Timer(const Duration(seconds: 3), startInitialLoad);

    // =================================================
    // DISPOSE
    // =================================================

    controller.onCancel = () async {
      disposed = true;

      reloadTimer?.cancel();
      reloadTimer = null;

      initialFallbackTimer?.cancel();
      initialFallbackTimer = null;

      final currentChannel = channel;

      channel = null;

      if (currentChannel != null) {
        await _client.removeChannel(currentChannel);
      }

      if (!controller.isClosed) {
        await controller.close();
      }
    };

    return controller.stream;
  }

  // ===================================================
  // SORT
  // ===================================================

  int _compareQueueItems(RoomQueueItem a, RoomQueueItem b) {
    final positionCompare = a.position.compareTo(b.position);

    if (positionCompare != 0) {
      return positionCompare;
    }

    final timeCompare = a.createdAt.compareTo(b.createdAt);

    if (timeCompare != 0) {
      return timeCompare;
    }

    return a.id.compareTo(b.id);
  }

  // ===================================================
  // MAP
  // ===================================================

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
