class RoomMessageReplyPreview {
  const RoomMessageReplyPreview({
    required this.messageId,
    required this.userId,
    required this.userName,
    required this.content,
  });

  final String messageId;
  final String userId;
  final String userName;
  final String content;
}

class RoomMessage {
  const RoomMessage({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.content,
    required this.createdAt,
    required this.userName,
    this.avatarUrl,
    this.reply,
  });

  final String id;
  final String roomId;
  final String userId;

  final String content;

  final DateTime createdAt;

  final String userName;
  final String? avatarUrl;

  final RoomMessageReplyPreview? reply;

  bool isOwn(String? currentUserId) {
    return currentUserId != null &&
        userId == currentUserId;
  }
}