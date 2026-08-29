import 'room_exit_registration.dart';

class NoopRoomExitRegistration implements RoomExitRegistration {
  const NoopRoomExitRegistration();

  @override
  Future<void> register({required String cleanupToken}) async {}

  @override
  Future<void> clear() async {}
}
