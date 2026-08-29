class Room {
  final String id;
  final String roomCode;
  final String name;
  final String hostId;
  final DateTime createdAt;

  const Room({
    required this.id,
    required this.roomCode,
    required this.name,
    required this.hostId,
    required this.createdAt,
  });
}
