import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/providers/room_chat_repository_provider.dart';
import '../../domain/models/room_message.dart';

final roomChatControllerProvider = AsyncNotifierProvider.autoDispose
    .family<RoomChatController, List<RoomMessage>, String>(
      RoomChatController.new,
    );

class RoomChatController extends AsyncNotifier<List<RoomMessage>> {
  RoomChatController(this.roomId);

  final String roomId;

  StreamSubscription<List<RoomMessage>>? _subscription;

  bool _loadingOlder = false;
  bool _hasMore = true;

  @override
  Future<List<RoomMessage>> build() async {
    final repository = ref.read(roomChatRepositoryProvider);

    final completer = Completer<List<RoomMessage>>();

    _subscription = repository
        .watchMessages(roomId)
        .listen(
          (messages) {
            // Первый список.
            if (!completer.isCompleted) {
              completer.complete(messages);

              return;
            }

            _mergeLiveMessages(messages);
          },

          onError: (Object error, StackTrace stackTrace) {
            if (!completer.isCompleted) {
              completer.completeError(error, stackTrace);

              return;
            }

            state = AsyncError(error, stackTrace);
          },
        );

    ref.onDispose(() {
      _subscription?.cancel();
    });

    return completer.future;
  }

  // ===================================================
  // LIVE MERGE
  // ===================================================

  void _mergeLiveMessages(List<RoomMessage> liveMessages) {
    final current = state.value ?? const [];

    final byId = <String, RoomMessage>{};

    // Сначала сохраняем старую историю,
    // которую могли получить pagination.
    for (final message in current) {
      byId[message.id] = message;
    }

    // Потом обновляем realtime сообщения.
    for (final message in liveMessages) {
      byId[message.id] = message;
    }

    final merged = byId.values.toList()..sort(_compareMessages);

    state = AsyncData(merged);
  }

  // ===================================================
  // LOAD OLDER
  // ===================================================

  Future<bool> loadOlder() async {
    if (_loadingOlder || !_hasMore) {
      return false;
    }

    final current = state.value;

    if (current == null || current.isEmpty) {
      return false;
    }

    _loadingOlder = true;

    try {
      final oldest = current.first;

      const pageSize = 50;

      final older = await ref
          .read(roomChatRepositoryProvider)
          .getMessages(roomId, limit: pageSize, before: oldest.createdAt);

      if (older.length < pageSize) {
        _hasMore = false;
      }

      if (older.isEmpty) {
        return false;
      }

      final byId = <String, RoomMessage>{};

      for (final message in older) {
        byId[message.id] = message;
      }

      for (final message in current) {
        byId[message.id] = message;
      }

      final merged = byId.values.toList()..sort(_compareMessages);

      state = AsyncData(merged);

      return true;
    } finally {
      _loadingOlder = false;
    }
  }

  // ===================================================
  // SEND
  // ===================================================

  Future<void> sendMessage(String content, {String? replyToMessageId}) async {
    final normalized = content.trim();

    if (normalized.isEmpty) {
      return;
    }

    final user = ref.read(authControllerProvider).user;

    if (user == null) {
      throw StateError('User is not authenticated.');
    }

    await ref
        .read(roomChatRepositoryProvider)
        .sendMessage(
          roomId: roomId,
          userId: user.id,
          content: normalized,
          replyToMessageId: replyToMessageId,
        );
  }

  // ===================================================
  // SORT
  // ===================================================

  int _compareMessages(RoomMessage a, RoomMessage b) {
    final timeCompare = a.createdAt.compareTo(b.createdAt);

    if (timeCompare != 0) {
      return timeCompare;
    }

    return a.id.compareTo(b.id);
  }
}
