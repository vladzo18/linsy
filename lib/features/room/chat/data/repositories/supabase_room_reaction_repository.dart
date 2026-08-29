import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/room_message_reaction.dart';
import '../../domain/repositories/room_reaction_repository.dart';

class SupabaseRoomReactionRepository implements RoomReactionRepository {
  SupabaseRoomReactionRepository(this._client);

  final SupabaseClient _client;

  // ===================================================
  // GET
  // ===================================================

  @override
  Future<List<RoomMessageReaction>> getReactions(String roomId) async {
    final data = await _client
        .from('room_message_reactions')
        .select('''
          message_id,
          user_id,
          reaction,
          created_at
          ''')
        .eq('room_id', roomId);

    final reactions = <RoomMessageReaction>[];

    for (final row in data) {
      final reaction = row['reaction'];

      // NULL означает, что пользователь
      // снял свою реакцию.
      if (reaction is! String || reaction.isEmpty) {
        continue;
      }

      reactions.add(
        RoomMessageReaction(
          messageId: row['message_id'] as String,
          userId: row['user_id'] as String,
          reaction: reaction,
          createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
        ),
      );
    }

    return reactions;
  }

  // ===================================================
  // WATCH
  // ===================================================

  @override
  Stream<List<RoomMessageReaction>> watchReactions(String roomId) {
    late final StreamController<List<RoomMessageReaction>> controller;

    RealtimeChannel? channel;

    bool loading = false;
    bool reloadRequested = false;
    bool disposed = false;

    // -------------------------------------------------
    // RELOAD
    // -------------------------------------------------

    Future<void> reload() async {
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

          final reactions = await getReactions(roomId);

          if (!disposed && !controller.isClosed) {
            controller.add(reactions);
          }
        } while (reloadRequested && !disposed);
      } catch (error, stackTrace) {
        if (!disposed && !controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      } finally {
        loading = false;
      }
    }

    // -------------------------------------------------
    // STREAM
    // -------------------------------------------------

    controller = StreamController<List<RoomMessageReaction>>(
      onListen: () {
        channel = _client.channel('room-reactions:$roomId');

        channel!
            // =========================================
            // FIRST REACTION
            // =========================================
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'room_message_reactions',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'room_id',
                value: roomId,
              ),
              callback: (payload) {
                unawaited(reload());
              },
            )
            // =========================================
            // CHANGE / REMOVE REACTION
            // =========================================
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'room_message_reactions',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'room_id',
                value: roomId,
              ),
              callback: (payload) {
                unawaited(reload());
              },
            )
            .subscribe();

        unawaited(reload());
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
  // TOGGLE
  // ===================================================

  @override
  Future<void> toggleReaction({
    required String messageId,
    required String reaction,
  }) async {
    final normalized = reaction.trim();

    if (normalized.isEmpty) {
      return;
    }

    await _client.rpc(
      'toggle_room_message_reaction',
      params: {'p_message_id': messageId, 'p_reaction': normalized},
    );
  }
}
