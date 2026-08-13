import  'room_repository.dart';
import '../../domain/models/room.dart';

class SupabaseRoomRepository implements RoomRepository {
  @override
  Future<Room> createRoom({
    required String name,
    required String hostId,
  }) async {
    // Simulate a network request to create a room
    await Future.delayed(const Duration(milliseconds: 500));

    // Return a dummy Room object
    return Room(
      id: 'ABC123',
      name: name,
      hostId: hostId,
    );
  }

  @override
  Future<Room?> getRoom(String roomId) async {
    // Simulate a network request to get a room
    await Future.delayed(const Duration(milliseconds: 500));

    // Return a dummy Room object if the roomId matches, otherwise return null
    if (roomId == 'ABC123') {
      return Room(
        id: 'ABC123',
        name: 'Sample Room',
        hostId: 'host123',
      );
    } else {
      return null;
    }
  }
}