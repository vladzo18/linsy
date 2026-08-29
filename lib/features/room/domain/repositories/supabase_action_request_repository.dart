import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/room_action_request.dart';
import '../../domain/repositories/action_request_repository.dart';

class SupabaseActionRequestRepository implements ActionRequestRepository {
  final SupabaseClient _client;

  SupabaseActionRequestRepository(this._client);

  @override
  Future<List<RoomActionRequest>> getRoomRequests(String roomId) {
    return _getRequests(roomId);
  }

  Future<List<RoomActionRequest>> _getRequests(
    String roomId, {
    String? userId,
  }) async {
    final baseQuery = _client
        .from('room_action_requests')
        .select()
        .eq('room_id', roomId);

    final filteredQuery = userId != null
        ? baseQuery.eq('user_id', userId)
        : baseQuery;

    final rows = await filteredQuery.order('created_at', ascending: true);

    return rows
        .map((row) => _mapRequest(Map<String, dynamic>.from(row)))
        .toList();
  }

  @override
  Future<RoomActionRequest> createRequest({
    required String roomId,
    required String userId,
    required RoomAction action,
    Map<String, dynamic>? payload,
  }) async {
    final response = await _client
        .from('room_action_requests')
        .insert({
          'room_id': roomId,
          'user_id': userId,
          'action': action.value,
          'payload': payload,
        })
        .select()
        .single();

    return _mapRequest(response);
  }

  @override
  Future<void> cancelRequest({required String requestId}) async {
    await _client
        .from('room_action_requests')
        .update({'status': 'cancelled'})
        .eq('id', requestId);
  }

  @override
  Future<void> resolveRequest({
    required String requestId,
    required RoomActionRequestStatus status,
  }) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw StateError('Not authenticated.');
    }

    await _client
        .from('room_action_requests')
        .update({
          'status': status.name,
          'resolved_at': DateTime.now().toUtc().toIso8601String(),
          'resolved_by': user.id,
        })
        .eq('id', requestId);
  }

  @override
  Stream<List<RoomActionRequest>> watchRoomRequests(String roomId) {
    return _watchRoomRequests(roomId);
  }

  @override
  Stream<List<RoomActionRequest>> watchMyRequests(
    String roomId,
    String userId,
  ) {
    return _watchRoomRequests(roomId, userId: userId);
  }

  Stream<List<RoomActionRequest>> _watchRoomRequests(
    String roomId, {
    String? userId,
  }) {
    final controller = StreamController<List<RoomActionRequest>>();

    RealtimeChannel? channel;

    Future<void> loadRequests() async {
      try {
        final requests = await _getRequests(roomId, userId: userId);

        if (!controller.isClosed) {
          controller.add(requests);
        }
      } catch (error, stackTrace) {
        if (!controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      }
    }

    () async {
      await loadRequests();

      channel = _client
          .channel(
            'room-action-requests-$roomId-${DateTime.now().microsecondsSinceEpoch}',
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'room_action_requests',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'room_id',
              value: roomId,
            ),
            callback: (payload) {
              loadRequests();
            },
          )
          .subscribe();
    }();

    controller.onCancel = () async {
      final currentChannel = channel;

      if (currentChannel != null) {
        await _client.removeChannel(currentChannel);
      }

      await controller.close();
    };

    return controller.stream;
  }

  RoomActionRequest _mapRequest(Map<String, dynamic> data) {
    return RoomActionRequest(
      id: data['id'] as String,
      roomId: data['room_id'] as String,
      userId: data['user_id'] as String,
      action: RoomAction.fromString(data['action'] as String),
      payload: data['payload'] == null
          ? null
          : Map<String, dynamic>.from(data['payload'] as Map),
      status: RoomActionRequestStatus.fromString(data['status'] as String),
      createdAt: DateTime.parse(data['created_at'] as String),
      resolvedAt: data['resolved_at'] == null
          ? null
          : DateTime.parse(data['resolved_at'] as String),
      resolvedBy: data['resolved_by'] as String?,
    );
  }
}
