import '../models/room_message_reaction.dart';

abstract interface class RoomReactionRepository {
  Future<List<RoomMessageReaction>> getReactions(String roomId);

  Stream<List<RoomMessageReaction>> watchReactions(String roomId);

  Future<void> toggleReaction({
    required String messageId,
    required String reaction,
  });
}
