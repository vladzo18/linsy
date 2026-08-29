import '../models/room_message.dart';

abstract interface class RoomChatRepository {
  Future<List<RoomMessage>> getMessages(
    String roomId, {
    int limit = 100,
    DateTime? before,
  });

  Stream<List<RoomMessage>> watchMessages(String roomId);

  Future<void> sendMessage({
    required String roomId,
    required String userId,
    required String content,
    String? replyToMessageId,
  });
}
