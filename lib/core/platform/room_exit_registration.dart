abstract interface class RoomExitRegistration {
  Future<void> register({required String cleanupToken});

  Future<void> clear();
}
