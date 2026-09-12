import 'package:flutter/material.dart';

import '../../domain/models/room_message_reaction.dart';
import '../reactions/reaction_catalog.dart';

import 'message_reaction_visual.dart';

class MessageActionsPanel extends StatefulWidget {
  const MessageActionsPanel({
    super.key,
    required this.currentUserId,
    required this.reactions,
    required this.onReaction,
    required this.onReply,
  });

  final String? currentUserId;

  final List<RoomMessageReaction> reactions;

  final Future<void> Function(String reaction) onReaction;

  final VoidCallback onReply;

  @override
  State<MessageActionsPanel> createState() => _MessageActionsPanelState();
}

class _MessageActionsPanelState extends State<MessageActionsPanel> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final all = ReactionCatalog.all;

    final quick = all.take(4).toList();

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final reaction in quick)
                  _QuickReactionButton(
                    reaction: reaction,
                    selected: _isSelected(reaction.id),
                    onPressed: () {
                      widget.onReaction(reaction.id);
                    },
                  ),

                _MessageActionButton(
                  tooltip: 'More reactions',
                  icon: Icons.add_reaction_outlined,
                  selected: _showAll,
                  onPressed: () {
                    setState(() {
                      _showAll = !_showAll;
                    });
                  },
                ),

                _MessageActionButton(
                  tooltip: 'Reply',
                  icon: Icons.reply_rounded,
                  onPressed: widget.onReply,
                ),
              ],
            ),

            if (_showAll) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 5),
                child: Divider(height: 1),
              ),

              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 300,
                  maxHeight: 240,
                ),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final reaction in all)
                        SizedBox.square(
                          dimension: 42,
                          child: _ReactionGridItem(
                            reaction: reaction,
                            selected: _isSelected(reaction.id),
                            onPressed: () {
                              widget.onReaction(reaction.id);
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _isSelected(String reactionId) {
    final userId = widget.currentUserId;

    if (userId == null) {
      return false;
    }

    return widget.reactions.any(
      (reaction) =>
          reaction.reaction == reactionId && reaction.userId == userId,
    );
  }
}

// QUICK REACTION

class _QuickReactionButton extends StatelessWidget {
  const _QuickReactionButton({
    required this.reaction,
    required this.selected,
    required this.onPressed,
  });

  final ReactionDefinition reaction;

  final bool selected;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Tooltip(
      message: reaction.id,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: Material(
          color: selected ? colors.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: MessageReactionVisual(reactionId: reaction.id, size: 25),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ACTION BUTTON

class _MessageActionButton extends StatelessWidget {
  const _MessageActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.selected = false,
  });

  final String tooltip;

  final IconData icon;

  final VoidCallback onPressed;

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: Material(
          color: selected ? colors.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(width: 40, height: 40, child: Icon(icon, size: 20)),
          ),
        ),
      ),
    );
  }
}

// REACTION GRID ITEM

class _ReactionGridItem extends StatelessWidget {
  const _ReactionGridItem({
    required this.reaction,
    required this.selected,
    required this.onPressed,
  });

  final ReactionDefinition reaction;

  final bool selected;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Tooltip(
      message: reaction.id,
      child: Material(
        color: selected ? colors.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Center(
            child: MessageReactionVisual(reactionId: reaction.id, size: 27),
          ),
        ),
      ),
    );
  }
}
