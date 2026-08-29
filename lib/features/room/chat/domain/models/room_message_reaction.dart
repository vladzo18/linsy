class RoomMessageReaction {
  const RoomMessageReaction({
    required this.messageId,
    required this.userId,
    required this.reaction,
    required this.createdAt,
  });

  final String messageId;
  final String userId;
  final String reaction;
  final DateTime createdAt;
}