import '../../../application/sync/room_consistency_target.dart';
import '../../domain/models/room_message_reaction.dart';
import '../../domain/repositories/room_reaction_repository.dart';

typedef RoomReactionsReader = List<RoomMessageReaction>? Function();

typedef RoomReactionsWriter =
    void Function(List<RoomMessageReaction> reactions);

class RoomReactionSync implements RoomConsistencyTarget {
  RoomReactionSync({
    required this.roomId,
    required RoomReactionRepository repository,
    required RoomReactionsReader readReactions,
    required RoomReactionsWriter writeReactions,
  }) : _repository = repository,
       _readReactions = readReactions,
       _writeReactions = writeReactions;

  final String roomId;

  final RoomReactionRepository _repository;

  final RoomReactionsReader _readReactions;
  final RoomReactionsWriter _writeReactions;

  bool _syncing = false;
  bool _disposed = false;

  @override
  Future<void> resync() async {
    if (_disposed || _syncing) {
      return;
    }

    final beforeSync = _readReactions();

    // Initial load ещё не завершён.
    if (beforeSync == null) {
      return;
    }

    _syncing = true;

    try {
      final fetched = await _repository.getReactions(roomId);

      if (_disposed) {
        return;
      }

      final afterSync = _readReactions();

      if (afterSync == null) {
        return;
      }

      // Если Realtime успел обновить реакции,
      // пока выполнялся SELECT, не затираем
      // потенциально более свежее состояние.
      //
      // Realtime repository сам делает полный reload,
      // поэтому его результат уже является
      // полноценным snapshot БД.
      if (!identical(beforeSync, afterSync)) {
        return;
      }

      _writeReactions(fetched);
    } finally {
      _syncing = false;
    }
  }

  void dispose() {
    _disposed = true;
  }
}
