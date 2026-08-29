import '../../../application/sync/room_consistency_target.dart';
import '../../domain/models/room_message.dart';
import '../../domain/repositories/room_chat_repository.dart';
import 'room_chat_reconciler.dart';

typedef RoomChatMessagesReader = List<RoomMessage>? Function();

typedef RoomChatMessagesWriter = void Function(List<RoomMessage> messages);

class RoomChatSync implements RoomConsistencyTarget {
  RoomChatSync({
    required this.roomId,
    required RoomChatRepository repository,
    required RoomChatMessagesReader readMessages,
    required RoomChatMessagesWriter writeMessages,
  }) : _repository = repository,
       _readMessages = readMessages,
       _writeMessages = writeMessages;

  final String roomId;

  final RoomChatRepository _repository;

  final RoomChatMessagesReader _readMessages;
  final RoomChatMessagesWriter _writeMessages;

  bool _syncing = false;
  bool _disposed = false;

  static const int _syncWindowSize = 100;

  // ===================================================
  // SYNC
  // ===================================================

  @override
  Future<void> resync() async {
    if (_disposed || _syncing) {
      return;
    }

    final beforeSync = _readMessages();

    // Initial load ещё не завершён.
    if (beforeSync == null) {
      return;
    }

    _syncing = true;

    try {
      // +1 нужен RoomChatReconciler как sentinel.
      final fetched = await _repository.getMessages(
        roomId,
        limit: _syncWindowSize + 1,
      );

      if (_disposed) {
        return;
      }

      // Пока SELECT выполнялся,
      // Realtime мог изменить state.
      final afterSync = _readMessages();

      if (afterSync == null) {
        return;
      }

      final result = RoomChatReconciler.reconcileLatest(
        beforeSync: beforeSync,
        afterSync: afterSync,
        fetched: fetched,
        syncWindowSize: _syncWindowSize,
      );

      if (_disposed) {
        return;
      }

      _writeMessages(result);
    } finally {
      _syncing = false;
    }
  }

  void dispose() {
    _disposed = true;
  }
}
