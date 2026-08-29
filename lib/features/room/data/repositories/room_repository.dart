import 'package:linsy/features/auth/domain/models/app_user.dart';
import 'package:linsy/features/room/domain/models/room.dart';
import 'package:linsy/features/room/domain/models/room_member.dart';

abstract interface class RoomRepository {
  Future<Room> createRoom({required String name, required String hostId});

  Future<Room?> getRoomByCode(String roomCode);

  Stream<AppUser> watchProfileChanges();

  Future<Room?> getCurrentUserRoom(String userId);

  Future<List<Room>> getRoomsByIds(List<String> roomIds);

  Future<List<Room>> getMyRooms(String userId);

  Future<void> joinRoom({required String roomId, required String userId});

  Future<void> leaveRoom({required String roomId, required String userId});

  Future<void> deleteRoom({required String roomId, required String userId});

  Future<List<RoomMember>> getRoomMembers(String roomId);

  Stream<List<RoomMember>> watchRoomMembers(String roomId);

  Future<void> setMemberRole({
    required String roomId,
    required String userId,
    required RoomMemberRole role,
  });
}
