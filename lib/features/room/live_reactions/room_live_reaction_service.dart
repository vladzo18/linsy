import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// =====================================================================
// DEFINITIONS
// =====================================================================

class RoomLiveReactionDefinition {
  const RoomLiveReactionDefinition({
    required this.id,
    required this.emoji,
    required this.label,
  });

  final String id;
  final String emoji;
  final String label;
}

const roomLiveReactionDefinitions = <RoomLiveReactionDefinition>[
  RoomLiveReactionDefinition(id: 'fire', emoji: '🔥', label: 'Fire'),
  RoomLiveReactionDefinition(id: 'love', emoji: '😍', label: 'Love it'),
  RoomLiveReactionDefinition(id: 'laugh', emoji: '😂', label: 'Funny'),
  RoomLiveReactionDefinition(id: 'cry', emoji: '😭', label: 'Emotional'),
  RoomLiveReactionDefinition(id: 'skull', emoji: '💀', label: 'Dead'),
  RoomLiveReactionDefinition(id: 'clap', emoji: '👏', label: 'Applause'),
];

RoomLiveReactionDefinition? roomLiveReactionDefinitionById(String id) {
  for (final definition in roomLiveReactionDefinitions) {
    if (definition.id == id) {
      return definition;
    }
  }

  return null;
}

// =====================================================================
// EVENT
// =====================================================================

class RoomLiveReaction {
  const RoomLiveReaction({
    required this.id,
    required this.userId,
    required this.reactionId,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String reactionId;
  final DateTime createdAt;

  Map<String, dynamic> toPayload() {
    return {
      'id': id,
      'user_id': userId,
      'reaction_id': reactionId,
      'created_at_ms': createdAt.millisecondsSinceEpoch,
    };
  }

  static RoomLiveReaction? fromPayload(Map<String, dynamic> payload) {
    final id = payload['id'];
    final userId = payload['user_id'];
    final reactionId = payload['reaction_id'];

    if (id is! String || userId is! String || reactionId is! String) {
      return null;
    }

    if (roomLiveReactionDefinitionById(reactionId) == null) {
      return null;
    }

    final rawCreatedAt = payload['created_at_ms'];

    final createdAt = rawCreatedAt is num
        ? DateTime.fromMillisecondsSinceEpoch(rawCreatedAt.toInt(), isUtc: true)
        : DateTime.now().toUtc();

    return RoomLiveReaction(
      id: id,
      userId: userId,
      reactionId: reactionId,
      createdAt: createdAt,
    );
  }
}

// =====================================================================
// SERVICE
// =====================================================================

class RoomLiveReactionService {
  RoomLiveReactionService({
    required this._client,
    required this._roomId,
  });

  static const _eventName = 'reaction';

  static const _minimumSendInterval = Duration(milliseconds: 450);

  final SupabaseClient _client;
  final String _roomId;

  final StreamController<RoomLiveReaction> _controller =
      StreamController<RoomLiveReaction>.broadcast();

  RealtimeChannel? _channel;

  DateTime? _lastSentAt;

  int _sequence = 0;

  bool _disposed = false;

  Stream<RoomLiveReaction> get reactions => _controller.stream;

  // ===================================================================
  // START
  // ===================================================================

  void start() {
    if (_disposed || _channel != null) {
      return;
    }

    final channel = _client.channel('room-live-reactions:$_roomId');

    _channel = channel;

    channel
        .onBroadcast(
          event: _eventName,
          callback: (payload) {
            if (_disposed) {
              return;
            }

            final reaction = RoomLiveReaction.fromPayload(payload);

            if (reaction == null) {
              return;
            }

            _controller.add(reaction);
          },
        )
        .subscribe();
  }

  // ===================================================================
  // SEND
  // ===================================================================

  Future<bool> send({
    required String userId,
    required String reactionId,
  }) async {
    if (_disposed) {
      return false;
    }

    if (roomLiveReactionDefinitionById(reactionId) == null) {
      return false;
    }

    final now = DateTime.now().toUtc();

    final lastSentAt = _lastSentAt;

    if (lastSentAt != null &&
        now.difference(lastSentAt) < _minimumSendInterval) {
      return false;
    }

    _lastSentAt = now;

    _sequence++;

    final reaction = RoomLiveReaction(
      id:
          '$userId-'
          '${now.microsecondsSinceEpoch}-'
          '$_sequence',
      userId: userId,
      reactionId: reactionId,
      createdAt: now,
    );

    // ===============================================================
    // LOCAL
    //
    // Показываем реакцию отправителю мгновенно.
    // Broadcast по умолчанию не self-echo.
    // ===============================================================

    _controller.add(reaction);

    final channel = _channel;

    if (channel == null) {
      return false;
    }

    try {
      await channel.sendBroadcastMessage(
        event: _eventName,
        payload: reaction.toPayload(),
      );

      return true;
    } catch (_) {
      // Реакция уже была показана локально.
      // Для ephemeral события не показываем пользователю
      // раздражающий SnackBar из-за временной сети.
      return false;
    }
  }

  // ===================================================================
  // DISPOSE
  // ===================================================================

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    _disposed = true;

    final channel = _channel;

    _channel = null;

    if (channel != null) {
      await _client.removeChannel(channel);
    }

    await _controller.close();
  }
}

// =====================================================================
// PROVIDERS
// =====================================================================

final roomLiveReactionServiceProvider = Provider.autoDispose
    .family<RoomLiveReactionService, String>((ref, roomId) {
      final service = RoomLiveReactionService(
        client: Supabase.instance.client,
        roomId: roomId,
      );

      service.start();

      ref.onDispose(() {
        unawaited(service.dispose());
      });

      return service;
    });

final roomLiveReactionStreamProvider = StreamProvider.autoDispose
    .family<RoomLiveReaction, String>((ref, roomId) {
      final service = ref.watch(roomLiveReactionServiceProvider(roomId));

      return service.reactions;
    });
