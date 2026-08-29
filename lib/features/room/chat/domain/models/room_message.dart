class RoomMessageReplyPreview {
  const RoomMessageReplyPreview({
    required this.messageId,
    required this.userId,
    required this.content,
  });

  final String messageId;
  final String userId;
  final String content;
}

class RoomMessage {
  const RoomMessage({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.reply,
  });

  final String id;
  final String roomId;
  final String userId;
  final String content;
  final DateTime createdAt;

  final RoomMessageReplyPreview? reply;

  bool isOwn(String? currentUserId) {
    return currentUserId != null && userId == currentUserId;
  }
}
