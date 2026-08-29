import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'room_live_reaction_service.dart';

class RoomReactionButton extends ConsumerWidget {
  const RoomReactionButton({
    required this.roomId,
    required this.currentUserId,
    required this.compact,
    super.key,
  });

  final String roomId;
  final String? currentUserId;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (currentUserId == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: compact ? 54 : 104,
        child: Center(
          child: PopupMenuButton<void>(
            tooltip: 'React',
            padding: EdgeInsets.zero,
            position: PopupMenuPosition.over,
            itemBuilder: (context) {
              return [
                PopupMenuItem<void>(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: _ReactionPicker(
                    onSelected: (reactionId) {
                      Navigator.of(context).pop();

                      unawaited(
                        ref
                            .read(roomLiveReactionServiceProvider(roomId))
                            .send(
                              userId: currentUserId!,
                              reactionId: reactionId,
                            ),
                      );
                    },
                  ),
                ),
              ];
            },
            child: compact
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.add_reaction_outlined, size: 24),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_reaction_outlined, size: 22),
                        const SizedBox(width: 7),
                        Text(
                          'React',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// PICKER
// =====================================================================

class _ReactionPicker extends StatelessWidget {
  const _ReactionPicker({required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 270,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final reaction in roomLiveReactionDefinitions)
            Tooltip(
              message: reaction.label,
              child: InkResponse(
                radius: 24,
                onTap: () {
                  onSelected(reaction.id);
                },
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: Text(
                      reaction.emoji,
                      style: const TextStyle(fontSize: 27, height: 1),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
