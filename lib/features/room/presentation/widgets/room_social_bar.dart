import 'package:flutter/material.dart';
import 'package:linsy/features/room/live_reactions/room_reaction_button.dart';
import '../controllers/room_state.dart';
import 'room_participants_bar.dart';

class RoomSocialBar extends StatelessWidget {
  const RoomSocialBar({
    super.key,
    required this.roomId,
    required this.roomState,
    required this.currentUserId,
    required this.compact,
  });

  final String roomId;
  final RoomState roomState;
  final String? currentUserId;

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: RoomParticipantsBar(
              roomId: roomId,
              roomState: roomState,
              currentUserId: currentUserId,
            ),
          ),

          SizedBox(width: compact ? 6 : 8),

          Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) {
              // Android can keep the chat TextField focused even after
              // the system keyboard was dismissed with the Back button.
              // Opening the reaction picker while that focus is still alive
              // can make the keyboard appear again.
              FocusManager.instance.primaryFocus?.unfocus();
            },
            child: RoomReactionButton(
              roomId: roomId,
              currentUserId: currentUserId,
              compact: compact,
            ),
          ),
        ],
      ),
    );
  }
}
