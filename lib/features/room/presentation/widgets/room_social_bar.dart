import '../../../../core/widgets/animated_content_swap.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../live_reactions/room_live_reaction_service.dart';
import 'package:flutter/material.dart';
import 'package:linsy/features/room/live_reactions/room_reaction_button.dart';
import '../controllers/room_state.dart';
import 'room_participants_bar.dart';

class RoomSocialBar extends ConsumerStatefulWidget {
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
  ConsumerState<RoomSocialBar> createState() => _RoomSocialBarState();
}

class _RoomSocialBarState extends ConsumerState<RoomSocialBar> {
  bool _open = false;
  @override
  Widget build(BuildContext context) {
    final roomId = widget.roomId;
    final roomState = widget.roomState;
    final currentUserId = widget.currentUserId;
    final compact = widget.compact;

    return SizedBox(
      height: 64,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: AnimatedContentSwap(
              child: _open
                  ? Card(
                      key: const ValueKey('reactions'),
                      margin: EdgeInsets.zero,
                      child: SizedBox(
                        height: 64,
                        child: Center(
                          child: RoomReactionPicker(
                            onSelected: (reactionId) {
                              setState(() => _open = false);
                              if (currentUserId == null) return;
                              unawaited(
                                ref
                                    .read(
                                      roomLiveReactionServiceProvider(roomId),
                                    )
                                    .send(
                                      userId: currentUserId,
                                      reactionId: reactionId,
                                    ),
                              );
                            },
                          ),
                        ),
                      ),
                    )
                  : RoomParticipantsBar(
                      key: const ValueKey('participants'),
                      roomId: roomId,
                      roomState: roomState,
                      currentUserId: currentUserId,
                    ),
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
              compact: compact,
              open: _open,
              onPressed: () => setState(() => _open = !_open),
            ),
          ),
        ],
      ),
    );
  }
}
