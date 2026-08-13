import '../../domain/models/room.dart';

abstract interface class RoomRepository {
  Future<Room> createRoom({
    required String name,
    required String hostId,
  });

  Future<Room?> getRoom(String roomId);
}