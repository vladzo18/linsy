import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/room_reaction_repository_provider.dart';
import '../../domain/models/room_message_reaction.dart';

final roomReactionControllerProvider = AsyncNotifierProvider.autoDispose
    .family<RoomReactionController, List<RoomMessageReaction>, String>(
      RoomReactionController.new,
    );

class RoomReactionController extends AsyncNotifier<List<RoomMessageReaction>> {
  RoomReactionController(this.roomId);

  final String roomId;

  StreamSubscription<List<RoomMessageReaction>>? _subscription;

  @override
  Future<List<RoomMessageReaction>> build() async {
    final repository = ref.read(roomReactionRepositoryProvider);

    final completer = Completer<List<RoomMessageReaction>>();

    _subscription = repository
        .watchReactions(roomId)
        .listen(
          (reactions) {
            if (!completer.isCompleted) {
              completer.complete(reactions);
              return;
            }

            state = AsyncData(reactions);
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!completer.isCompleted) {
              completer.completeError(error, stackTrace);
              return;
            }

            state = AsyncError(error, stackTrace);
          },
        );

    ref.onDispose(() {
      _subscription?.cancel();
    });

    return completer.future;
  }

  // ===================================================
  // TOGGLE
  // ===================================================

  Future<void> toggleReaction({
    required String messageId,
    required String reaction,
  }) async {
    await ref
        .read(roomReactionRepositoryProvider)
        .toggleReaction(messageId: messageId, reaction: reaction);
  }
}
