import 'room_consistency_target.dart';

typedef RoomSnapshotReader<T> = T? Function();
typedef RoomSnapshotLoader<T> = Future<T> Function();
typedef RoomSnapshotWriter<T> = void Function(T value);

typedef RoomSnapshotShouldApply<T> = bool Function(T current, T fetched);

class RoomSnapshotSync<T> implements RoomConsistencyTarget {
  RoomSnapshotSync({
    required this._read,
    required this._load,
    required this._write,
    this._shouldApply,
  });

  final RoomSnapshotReader<T> _read;
  final RoomSnapshotLoader<T> _load;
  final RoomSnapshotWriter<T> _write;

  final RoomSnapshotShouldApply<T>? _shouldApply;

  bool _syncing = false;
  bool _disposed = false;

  @override
  Future<void> resync() async {
    if (_disposed || _syncing) {
      return;
    }

    _syncing = true;

    try {
      // Максимум одна повторная попытка, если во время
      // SELECT пришёл Realtime event и изменил state.
      for (var attempt = 0; attempt < 2; attempt++) {
        final before = _read();

        // Контроллер ещё не загрузился.
        if (before == null) {
          return;
        }

        final fetched = await _load();

        if (_disposed) {
          return;
        }

        final after = _read();

        if (after == null) {
          return;
        }

        // Пока SELECT выполнялся, состояние изменилось.
        //
        // Не затираем более свежий Realtime snapshot.
        // Повторяем SELECT ещё один раз.
        if (!identical(before, after)) {
          continue;
        }

        final shouldApply = _shouldApply;

        if (shouldApply != null && !shouldApply(after, fetched)) {
          return;
        }

        _write(fetched);

        return;
      }
    } finally {
      _syncing = false;
    }
  }

  void dispose() {
    _disposed = true;
  }
}
