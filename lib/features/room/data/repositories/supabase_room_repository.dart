import 'dart:async';

import 'package:linsy/features/auth/domain/models/app_user.dart';
import 'package:linsy/features/room/data/repositories/room_repository.dart';
import 'package:linsy/features/room/domain/models/room_member.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/room.dart';

class SupabaseRoomRepository implements RoomRepository {
  final SupabaseClient _client;

  SupabaseRoomRepository(this._client);

  @override
  Future<Room> createRoom({
    required String name,
    required String hostId,
  }) async {
    final response = await _client.rpc(
      'create_room',
      params: {'p_name': name, 'p_host_id': hostId},
    );

    return _mapRoom(Map<String, dynamic>.from(response as Map));
  }

  @override
  Future<Room?> getRoomByCode(String roomCode) async {
    final response = await _client
        .from('rooms')
        .select()
        .eq('room_code', roomCode.toUpperCase())
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return _mapRoom(response);
  }

  @override
  Future<List<Room>> getRoomsByIds(List<String> roomIds) async {
    if (roomIds.isEmpty) {
      return [];
    }

    final response = await _client
        .from('rooms')
        .select()
        .inFilter('id', roomIds);

    return response
        .map((row) => _mapRoom(Map<String, dynamic>.from(row)))
        .toList();
  }

  @override
  Future<Room?> getCurrentUserRoom(String userId) async {
    final response = await _client
        .from('room_members')
        .select('rooms(*)')
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    final roomData = response['rooms'];

    if (roomData == null) {
      return null;
    }

    return _mapRoom(Map<String, dynamic>.from(roomData as Map));
  }

  @override
  Future<List<Room>> getMyRooms(String userId) async {
    final response = await _client
        .from('rooms')
        .select()
        .eq('host_id', userId)
        .order('created_at', ascending: false);

    return response
        .map((row) => _mapRoom(Map<String, dynamic>.from(row)))
        .toList();
  }

  @override
  Future<void> joinRoom({
    required String roomId,
    required String userId,
  }) async {
    await _client.rpc(
      'join_room',
      params: {'p_room_id': roomId, 'p_user_id': userId},
    );
  }

  @override
  Future<void> deleteRoom({
    required String roomId,
    required String userId,
  }) async {
    await _client.rpc(
      'delete_room',
      params: {'p_room_id': roomId, 'p_user_id': userId},
    );
  }

  @override
  Stream<List<RoomMember>> watchRoomMembers(String roomId) {
    final controller = StreamController<List<RoomMember>>();

    RealtimeChannel? channel;

    Future<void> loadMembers() async {
      try {
        final members = await getRoomMembers(roomId);

        if (!controller.isClosed) {
          controller.add(members);
        }
      } catch (error, stackTrace) {
        if (!controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      }
    }

    () async {
      await loadMembers();

      channel = _client
          .channel(
            'room-members-$roomId-${DateTime.now().microsecondsSinceEpoch}',
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'room_members',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'room_id',
              value: roomId,
            ),
            callback: (payload) {
              loadMembers();
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

  @override
  Future<void> leaveRoom({
    required String roomId,
    required String userId,
  }) async {
    await _client
        .from('room_members')
        .delete()
        .eq('room_id', roomId)
        .eq('user_id', userId);
  }

  Room _mapRoom(Map<String, dynamic> data) {
    return Room(
      id: data['id'] as String,
      roomCode: data['room_code'] as String,
      name: data['name'] as String,
      hostId: data['host_id'] as String,
      createdAt: DateTime.parse(data['created_at'] as String),
    );
  }

  @override
  Future<void> setMemberRole({
    required String roomId,
    required String userId,
    required RoomMemberRole role,
  }) async {
    if (role == RoomMemberRole.host) {
      throw ArgumentError('Host role cannot be assigned manually.');
    }

    await _client.rpc(
      'set_room_member_role',
      params: {
        'p_room_id': roomId,
        'p_target_user_id': userId,
        'p_role': role.name,
      },
    );
  }

  @override
  Future<List<RoomMember>> getRoomMembers(String roomId) async {
    final rows = await _client
        .from('room_members')
        .select()
        .eq('room_id', roomId)
        .order('joined_at', ascending: true);

    return rows.map((row) {
      final data = Map<String, dynamic>.from(row);

      return RoomMember(
        userId: data['user_id'] as String,

        // Оставь здесь тот mapping роли,
        // который у тебя используется сейчас.
        role: RoomMemberRole.fromString(data['role'] as String),

        joinedAt: DateTime.parse(data['joined_at'] as String),
      );
    }).toList();
  }
}
