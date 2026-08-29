import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/room_message.dart';
import '../../domain/repositories/room_chat_repository.dart';

class SupabaseRoomChatRepository implements RoomChatRepository {
  SupabaseRoomChatRepository(this._client);

  final SupabaseClient _client;

  // ===================================================
  // GET MESSAGES
  // ===================================================

  @override
  Future<List<RoomMessage>> getMessages(
    String roomId, {
    int limit = 100,
    DateTime? before,
  }) async {
    final safeLimit = limit.clamp(1, 500);

    final baseQuery = _client
        .from('room_messages')
        .select('''
        id,
        room_id,
        user_id,
        content,
        created_at,
        reply_to_message_id,

        profiles!room_messages_user_id_fkey (
          display_name,
          avatar_url
        )
        ''')
        .eq('room_id', roomId);

    final query = before == null
        ? baseQuery
        : baseQuery.lt('created_at', before.toUtc().toIso8601String());

    final data = await query
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(safeLimit);

    // ===================================================
    // FIRST PASS
    // ===================================================

    final baseMessages = <String, RoomMessage>{};

    for (final row in data) {
      final message = _mapBaseMessage(row);

      baseMessages[message.id] = message;
    }

    // ===================================================
    // FIND MISSING REPLIES
    // ===================================================
    //
    // Например:
    //
    // загружены сообщения 101..200
    // message 150 replies to message 20
    //
    // message 20 отсутствует в текущей странице,
    // поэтому догружаем только его.
    // ===================================================

    final missingReplyIds = <String>{};

    for (final row in data) {
      final replyToMessageId = row['reply_to_message_id'];

      if (replyToMessageId is String &&
          !baseMessages.containsKey(replyToMessageId)) {
        missingReplyIds.add(replyToMessageId);
      }
    }

    if (missingReplyIds.isNotEmpty) {
      final missingMessages = await _loadMessagesByIds(missingReplyIds);

      baseMessages.addAll(missingMessages);
    }

    // ===================================================
    // SECOND PASS
    // ===================================================

    final messages = <RoomMessage>[];

    for (final row in data) {
      final id = row['id'] as String;

      final baseMessage = baseMessages[id]!;

      RoomMessageReplyPreview? replyPreview;

      final replyToMessageId = row['reply_to_message_id'];

      if (replyToMessageId is String) {
        final original = baseMessages[replyToMessageId];

        if (original != null) {
          replyPreview = RoomMessageReplyPreview(
            messageId: original.id,
            userId: original.userId,
            userName: original.userName,
            content: original.content,
          );
        }
      }

      messages.add(
        RoomMessage(
          id: baseMessage.id,
          roomId: baseMessage.roomId,
          userId: baseMessage.userId,
          content: baseMessage.content,
          createdAt: baseMessage.createdAt,
          userName: baseMessage.userName,
          avatarUrl: baseMessage.avatarUrl,
          reply: replyPreview,
        ),
      );
    }

    return messages.reversed.toList();
  }

  Future<Map<String, RoomMessage>> _loadMessagesByIds(
    Iterable<String> messageIds,
  ) async {
    final ids = messageIds.toSet().toList();

    if (ids.isEmpty) {
      return {};
    }

    final data = await _client
        .from('room_messages')
        .select('''
        id,
        room_id,
        user_id,
        content,
        created_at,

        profiles!room_messages_user_id_fkey (
          display_name,
          avatar_url
        )
        ''')
        .inFilter('id', ids);

    final result = <String, RoomMessage>{};

    for (final row in data) {
      final message = _mapBaseMessage(row);

      result[message.id] = message;
    }

    return result;
  }
  // ===================================================
  // WATCH
  // ===================================================

  @override
  Stream<List<RoomMessage>> watchMessages(String roomId) {
    late final StreamController<List<RoomMessage>> controller;

    RealtimeChannel? channel;

    var messages = <RoomMessage>[];

    final authors = <String, _CachedAuthor>{};

    var disposed = false;

    // -------------------------------------------------
    // EMIT
    // -------------------------------------------------

    void emit() {
      if (disposed || controller.isClosed) {
        return;
      }

      controller.add(List.unmodifiable(messages));
    }

    // -------------------------------------------------
    // INITIAL LOAD
    // -------------------------------------------------

    Future<void> loadInitial() async {
      try {
        final initialMessages = await getMessages(roomId);

        if (disposed) {
          return;
        }

        final byId = <String, RoomMessage>{};

        for (final message in initialMessages) {
          byId[message.id] = message;

          authors[message.userId] = _CachedAuthor(
            name: message.userName,
            avatarUrl: message.avatarUrl,
          );
        }

        // Realtime INSERT мог прийти,
        // пока выполнялся initial SELECT.
        for (final message in messages) {
          byId[message.id] = message;
        }

        messages = byId.values.toList()..sort(_compareMessages);

        emit();
      } catch (error, stackTrace) {
        if (!disposed && !controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      }
    }

    // -------------------------------------------------
    // INSERT
    // -------------------------------------------------

    Future<void> handleInsert(Map<String, dynamic> record) async {
      if (disposed) {
        return;
      }

      final id = record['id'];

      final userId = record['user_id'];

      final recordRoomId = record['room_id'];

      final content = record['content'];

      final createdAtRaw = record['created_at'];

      final replyToMessageId = record['reply_to_message_id'];

      if (id is! String ||
          userId is! String ||
          recordRoomId is! String ||
          content is! String ||
          createdAtRaw is! String) {
        return;
      }

      if (recordRoomId != roomId) {
        return;
      }

      // Защита от повторного Realtime event.
      if (messages.any((message) => message.id == id)) {
        return;
      }

      var author = authors[userId];

      if (author == null) {
        author = await _loadAuthor(userId);

        authors[userId] = author;
      }

      if (disposed) {
        return;
      }

      RoomMessageReplyPreview? replyPreview;

      if (replyToMessageId is String) {
        // Сначала ищем локально.
        RoomMessage? original;

        for (final message in messages) {
          if (message.id == replyToMessageId) {
            original = message;
            break;
          }
        }

        // Если исходное сообщение уже выпало
        // из realtime окна — догружаем только его.
        if (original == null) {
          final loaded = await _loadMessagesByIds([replyToMessageId]);

          original = loaded[replyToMessageId];
        }

        if (original != null) {
          replyPreview = RoomMessageReplyPreview(
            messageId: original.id,
            userId: original.userId,
            userName: original.userName,
            content: original.content,
          );
        }
      }

      final message = RoomMessage(
        id: id,
        roomId: recordRoomId,
        userId: userId,
        content: content,
        createdAt: DateTime.parse(createdAtRaw).toUtc(),
        userName: author.name,
        avatarUrl: author.avatarUrl,
        reply: replyPreview,
      );

      messages.add(message);

      messages.sort(_compareMessages);

      // Realtime окно держим максимум 100 сообщений.
      if (messages.length > 100) {
        messages = messages.sublist(messages.length - 100);
      }

      emit();
    }

    // -------------------------------------------------
    // DELETE
    // -------------------------------------------------

    void handleDelete(Map<String, dynamic> record) {
      if (disposed) {
        return;
      }

      final id = record['id'];

      if (id is! String) {
        return;
      }

      final oldLength = messages.length;

      messages.removeWhere((message) => message.id == id);

      if (messages.length == oldLength) {
        return;
      }

      emit();
    }

    // -------------------------------------------------
    // REALTIME
    // -------------------------------------------------

    controller = StreamController<List<RoomMessage>>(
      onListen: () {
        channel = _client.channel('room-chat:$roomId');

        channel!
            // =========================================
            // INSERT
            // =========================================
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'room_messages',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'room_id',
                value: roomId,
              ),
              callback: (payload) {
                unawaited(handleInsert(payload.newRecord));
              },
            )
            // =========================================
            // DELETE
            // =========================================
            .onPostgresChanges(
              event: PostgresChangeEvent.delete,
              schema: 'public',
              table: 'room_messages',

              // Здесь специально НЕТ room_id filter.
              //
              // У DELETE oldRecord может содержать
              // только primary key.
              callback: (payload) {
                handleDelete(payload.oldRecord);
              },
            )
            // =========================================
            // SUBSCRIBE
            // =========================================
            .subscribe();

        unawaited(loadInitial());
      },

      onCancel: () async {
        disposed = true;

        final currentChannel = channel;

        if (currentChannel != null) {
          await _client.removeChannel(currentChannel);
        }

        if (!controller.isClosed) {
          await controller.close();
        }
      },
    );

    return controller.stream;
  }

  // ===================================================
  // LOAD AUTHOR
  // ===================================================

  Future<_CachedAuthor> _loadAuthor(String userId) async {
    final data = await _client
        .from('profiles')
        .select('''
              display_name,
              avatar_url
              ''')
        .eq('id', userId)
        .maybeSingle();

    if (data == null) {
      return const _CachedAuthor(name: 'Linsy user');
    }

    final displayName = data['display_name'];

    final avatar = data['avatar_url'];

    return _CachedAuthor(
      name: displayName is String && displayName.trim().isNotEmpty
          ? displayName.trim()
          : 'Linsy user',

      avatarUrl: avatar is String && avatar.trim().isNotEmpty
          ? avatar.trim()
          : null,
    );
  }

  // ===================================================
  // SEND
  // ===================================================

  @override
  Future<void> sendMessage({
    required String roomId,
    required String userId,
    required String content,
    String? replyToMessageId,
  }) async {
    final normalized = content.trim();

    if (normalized.isEmpty) {
      return;
    }

    if (normalized.length > 4000) {
      throw ArgumentError('Message cannot exceed 4000 characters.');
    }

    await _client.from('room_messages').insert({
      'room_id': roomId,
      'user_id': userId,
      'content': normalized,
      'reply_to_message_id': replyToMessageId,
    });
  }

  // ===================================================
  // MAPPER
  // ===================================================

  RoomMessage _mapBaseMessage(Map<String, dynamic> data) {
    final profileData = data['profiles'];

    String? displayName;
    String? avatarUrl;

    if (profileData is Map<String, dynamic>) {
      final name = profileData['display_name'];

      final avatar = profileData['avatar_url'];

      if (name is String && name.trim().isNotEmpty) {
        displayName = name.trim();
      }

      if (avatar is String && avatar.trim().isNotEmpty) {
        avatarUrl = avatar.trim();
      }
    }

    return RoomMessage(
      id: data['id'] as String,

      roomId: data['room_id'] as String,

      userId: data['user_id'] as String,

      content: data['content'] as String,

      createdAt: DateTime.parse(data['created_at'] as String).toUtc(),

      userName: displayName ?? 'Linsy user',

      avatarUrl: avatarUrl,

      reply: null,
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

// =====================================================================
// CACHED AUTHOR
// =====================================================================

class _CachedAuthor {
  const _CachedAuthor({required this.name, this.avatarUrl});

  final String name;
  final String? avatarUrl;
}
