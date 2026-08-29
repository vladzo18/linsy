import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/sync/room_consistency_coordinator_provider.dart';
import '../../application/sync/room_snapshot_sync.dart';
import '../../data/providers/queue_repository_provider.dart';
import '../../domain/models/room_queue_item.dart';
import '../../domain/repositories/queue_repository.dart';

final queueControllerProvider = AsyncNotifierProvider.autoDispose
    .family<QueueController, List<RoomQueueItem>, String>(QueueController.new);

class QueueController extends AsyncNotifier<List<RoomQueueItem>> {
  QueueController(this.roomId);

  final String roomId;

  StreamSubscription<List<RoomQueueItem>>? _subscription;

  bool _disposed = false;

  // Пока выполняется ADD / REMOVE / REORDER,
  // внешние snapshots не должны перезаписывать
  // optimistic state.
  bool _mutationInProgress = false;

  // Если Realtime/consistency что-то прислали
  // во время mutation, после RPC перечитаем БД
  // ещё раз.
  bool _externalChangedDuringMutation = false;

  // Локальные mutations выполняются строго
  // последовательно.
  Future<void> _mutationTail = Future<void>.value();

  // ===================================================
  // BUILD
  // ===================================================

  @override
  Future<List<RoomQueueItem>> build() async {
    final repository = ref.read(queueRepositoryProvider);

    final consistencyCoordinator = ref.watch(
      roomConsistencyCoordinatorProvider(roomId),
    );

    final queueSync = RoomSnapshotSync<List<RoomQueueItem>>(
      read: () => state.value,

      load: () => repository.getQueue(roomId),

      write: _applyExternalSnapshot,
    );

    final unregisterSync = consistencyCoordinator.register(queueSync);

    final completer = Completer<List<RoomQueueItem>>();

    // =================================================
    // REALTIME
    // =================================================

    _subscription = repository
        .watchQueue(roomId)
        .listen(
          (items) {
            if (!completer.isCompleted) {
              completer.complete(items);
            }

            _applyExternalSnapshot(items);
          },
          onError: (Object error, StackTrace stackTrace) {
            // Ошибка initial load действительно
            // мешает построить controller.
            if (!completer.isCompleted) {
              completer.completeError(error, stackTrace);

              return;
            }

            // После того как queue уже была загружена,
            // временная ошибка Realtime/SELECT не должна
            // уничтожать существующий UI.
            //
            // Network/consistency layer позже выполнит
            // восстановление.
          },
        );

    // =================================================
    // DISPOSE
    // =================================================

    ref.onDispose(() {
      _disposed = true;

      unregisterSync();

      queueSync.dispose();

      unawaited(_subscription?.cancel());

      _subscription = null;
    });

    return completer.future;
  }

  // ===================================================
  // EXTERNAL SNAPSHOT
  // ===================================================

  void _applyExternalSnapshot(List<RoomQueueItem> items) {
    if (_disposed) {
      return;
    }

    if (_mutationInProgress) {
      _externalChangedDuringMutation = true;
      return;
    }

    state = AsyncData(items);
  }

  // ===================================================
  // ADD
  // ===================================================

  Future<void> addItem({
    required String trackId,
    String? title,
    String? thumbnailUrl,
    int? durationMs,
    String source = 'youtube',
  }) {
    return _enqueueMutation<void>(() async {
      final repository = ref.read(queueRepositoryProvider);

      final previous = state.value ?? const <RoomQueueItem>[];

      await _performMutation(
        repository: repository,
        previous: previous,

        mutate: () async {
          await repository.addItem(
            roomId: roomId,
            trackId: trackId,
            title: title,
            thumbnailUrl: thumbnailUrl,
            durationMs: durationMs,
            source: source,
          );
        },
      );
    });
  }

  // ===================================================
  // REMOVE
  // ===================================================

  Future<void> removeItem(String itemId) {
    return _enqueueMutation<void>(() async {
      final repository = ref.read(queueRepositoryProvider);

      final previous = state.value ?? const <RoomQueueItem>[];

      final exists = previous.any((item) => item.id == itemId);

      if (!exists) {
        return;
      }

      final optimistic = _reindex(
        previous.where((item) => item.id != itemId).toList(),
      );

      await _performMutation(
        repository: repository,
        previous: previous,
        optimistic: optimistic,

        mutate: () async {
          await repository.removeItem(itemId: itemId);
        },
      );
    });
  }

  // ===================================================
  // REORDER
  // ===================================================

  Future<List<RoomQueueItem>> reorderItem({
    required String itemId,
    required int newIndex,
  }) {
    return _enqueueMutation<List<RoomQueueItem>>(() async {
      final repository = ref.read(queueRepositoryProvider);

      final previous = state.value ?? const <RoomQueueItem>[];

      final oldIndex = previous.indexWhere((item) => item.id == itemId);

      if (oldIndex < 0 ||
          newIndex < 0 ||
          newIndex >= previous.length ||
          oldIndex == newIndex) {
        return previous;
      }

      // =================================================
      // OPTIMISTIC ORDER
      // =================================================

      final optimistic = List<RoomQueueItem>.from(previous);

      final moved = optimistic.removeAt(oldIndex);

      optimistic.insert(newIndex, moved);

      final normalizedOptimistic = _reindex(optimistic);

      return _performMutation(
        repository: repository,
        previous: previous,
        optimistic: normalizedOptimistic,

        mutate: () async {
          // RPC сам выполняет canonical reorder
          // в Postgres.
          await repository.reorderItem(
            roomId: roomId,
            itemId: itemId,
            newIndex: newIndex,
          );
        },
      );
    });
  }

  // ===================================================
  // MUTATION SERIALIZATION
  // ===================================================

  Future<T> _enqueueMutation<T>(Future<T> Function() operation) {
    final completer = Completer<T>();

    _mutationTail = _mutationTail.then((_) async {
      if (_disposed) {
        if (!completer.isCompleted) {
          completer.completeError(StateError('QueueController is disposed.'));
        }

        return;
      }

      try {
        final result = await operation();

        if (!completer.isCompleted) {
          completer.complete(result);
        }
      } catch (error, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      }
    });

    return completer.future;
  }

  // ===================================================
  // MUTATION
  // ===================================================

  Future<List<RoomQueueItem>> _performMutation({
    required QueueRepository repository,
    required List<RoomQueueItem> previous,
    required Future<void> Function() mutate,
    List<RoomQueueItem>? optimistic,
  }) async {
    _mutationInProgress = true;

    _externalChangedDuringMutation = false;

    if (optimistic != null && !_disposed) {
      state = AsyncData(optimistic);
    }

    try {
      await mutate();

      // RPC response сам по себе уже хороший,
      // но мы дополнительно читаем БД после commit.
      //
      // Это защищает от ситуации:
      //
      // Device A reorder
      // Device B reorder сразу после
      //
      // → получаем уже последний порядок.
      final authoritative = await _readAuthoritativeUntilQuiet(repository);

      if (!_disposed) {
        state = AsyncData(authoritative);
      }

      return authoritative;
    } catch (error, stackTrace) {
      // Важный случай:
      //
      // сервер мог выполнить mutation,
      // но клиент потерял ответ.
      //
      // Поэтому сначала пытаемся узнать
      // реальное состояние БД и только потом
      // откатываем optimistic state.
      try {
        final authoritative = await _readAuthoritativeUntilQuiet(repository);

        if (!_disposed) {
          state = AsyncData(authoritative);
        }
      } catch (_) {
        if (!_disposed) {
          state = AsyncData(previous);
        }
      }

      Error.throwWithStackTrace(error, stackTrace);
    } finally {
      _mutationInProgress = false;

      _externalChangedDuringMutation = false;
    }
  }

  // ===================================================
  // AUTHORITATIVE READ
  // ===================================================

  Future<List<RoomQueueItem>> _readAuthoritativeUntilQuiet(
    QueueRepository repository,
  ) async {
    List<RoomQueueItem> latest = const <RoomQueueItem>[];

    // Обычно потребуется только один SELECT.
    //
    // Повторяем, только если во время SELECT
    // Realtime/consistency сообщили,
    // что queue снова изменилась.
    for (var attempt = 0; attempt < 3; attempt++) {
      _externalChangedDuringMutation = false;

      latest = await repository.getQueue(roomId);

      if (!_externalChangedDuringMutation) {
        return latest;
      }
    }

    return latest;
  }

  // ===================================================
  // LOCAL ZERO-BASED POSITIONS
  // ===================================================

  List<RoomQueueItem> _reindex(List<RoomQueueItem> items) {
    return [
      for (var index = 0; index < items.length; index++)
        _withPosition(items[index], index),
    ];
  }

  RoomQueueItem _withPosition(RoomQueueItem item, int position) {
    return RoomQueueItem(
      id: item.id,
      roomId: item.roomId,
      source: item.source,
      trackId: item.trackId,
      title: item.title,
      thumbnailUrl: item.thumbnailUrl,
      durationMs: item.durationMs,
      position: position,
      addedBy: item.addedBy,
      createdAt: item.createdAt,
    );
  }
}
