import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../profile/application/profile_store.dart';
import '../../domain/models/room_message.dart';
import '../../domain/models/room_message_reaction.dart';
import '../reactions/reaction_catalog.dart';

import 'message_reaction_chips.dart';
import 'message_metadata.dart';
import 'message_actions_panel.dart';
import 'message_reply_preview.dart';

class RoomMessageBubble extends ConsumerStatefulWidget {
  const RoomMessageBubble({
    required this.message,
    required this.isOwn,
    required this.currentUserId,
    required this.reactions,
    required this.onReply,
    required this.onToggleReaction,
    super.key,
  });

  final RoomMessage message;

  final bool isOwn;

  final String? currentUserId;

  final List<RoomMessageReaction> reactions;

  final VoidCallback onReply;

  final Future<void> Function(String reaction) onToggleReaction;

  @override
  ConsumerState<RoomMessageBubble> createState() => _RoomMessageBubbleState();
}

// MESSAGE

class _RoomMessageBubbleState extends ConsumerState<RoomMessageBubble> {
  final MenuController _actionsController = MenuController();

  // ACTION MENU

  void _openActions() {
    if (_actionsController.isOpen) {
      return;
    }

    _actionsController.open();
  }

  void _closeActions() {
    if (!_actionsController.isOpen) {
      return;
    }

    _actionsController.close();
  }

  // BUILD

  @override
  Widget build(BuildContext context) {
    // AUTHOR PROFILE
    //
    // Имя и аватар сообщения больше НЕ хранятся/берутся
    // из RoomMessage или RoomMember.
    //
    // Единственный источник истины:
    //
    // message.userId
    //      ↓
    // ProfileStore

    final profile = ref.watch(profileByIdProvider(widget.message.userId));

    final profileName = profile?.displayName?.trim();

    final displayName = profileName != null && profileName.isNotEmpty
        ? profileName
        : 'Linsy user';

    final avatarUrl = profile?.avatarUrl;

    final colors = Theme.of(context).colorScheme;

    final bubbleColor = widget.isOwn
        ? colors.primaryContainer
        : colors.surfaceContainerHighest;

    final textColor = widget.isOwn
        ? colors.onPrimaryContainer
        : colors.onSurface;

    final summaries = _buildReactionSummaries();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Чужое сообщение использует:
          //
          // 32 px avatar
          // 8 px gap
          //
          // Поэтому bubble получает немного меньше места.

          final avatarSpace = widget.isOwn ? 0.0 : 40.0;

          final availableBubbleWidth = math.max(
            0.0,
            constraints.maxWidth - avatarSpace,
          );

          // Максимум примерно 78% области сообщения.

          final maxBubbleWidth = math.min(
            availableBubbleWidth,
            math.max(96.0, availableBubbleWidth * 0.78),
          );

          // CONTENT-BASED MIN WIDTH

          final reactionRowWidth = _preferredReactionRowWidth(summaries);

          var preferredMinWidth = 96.0;

          if (reactionRowWidth > 0) {
            // +26 = horizontal padding bubble.
            preferredMinWidth = math.max(
              preferredMinWidth,
              reactionRowWidth + 34,
            );
          }

          if (widget.message.reply != null) {
            // Reply preview имеет minWidth 140,
            // плюс padding самого bubble.
            preferredMinWidth = math.max(preferredMinWidth, 166);
          }

          final minBubbleWidth = math.min(preferredMinWidth, maxBubbleWidth);

          // Внутренняя максимальная ширина
          // после padding 13 + 13.

          final maxContentWidth = math.max(0.0, maxBubbleWidth - 26);

          // Примерная ширина времени HH:mm.

          const timeWidth = 48.0;
          const timeGap = 10.0;

          final reactionAreaMaxWidth = math.max(
            20.0,
            maxContentWidth - timeWidth - timeGap,
          );

          final bubble = ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: minBubbleWidth,
              maxWidth: maxBubbleWidth,
            ),
            child: IntrinsicWidth(
              child: MenuAnchor(
                controller: _actionsController,
                consumeOutsideTap: false,
                style: MenuStyle(
                  padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                  maximumSize: const WidgetStatePropertyAll(Size(340, 380)),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),

                // ACTION MENU
                menuChildren: [
                  MessageActionsPanel(
                    currentUserId: widget.currentUserId,
                    reactions: widget.reactions,
                    onReaction: (reaction) async {
                      _closeActions();

                      await widget.onToggleReaction(reaction);
                    },
                    onReply: () {
                      _closeActions();

                      widget.onReply();
                    },
                  ),
                ],

                // BUBBLE
                builder: (context, controller, child) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _openActions,
                    onLongPress: _openActions,
                    onSecondaryTapDown: (_) {
                      _openActions();
                    },
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(widget.isOwn ? 18 : 5),
                          bottomRight: Radius.circular(widget.isOwn ? 5 : 18),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(13, 9, 13, 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // REPLY
                            if (widget.message.reply != null) ...[
                              MessageReplyPreview(
                                reply: widget.message.reply!,
                                textColor: textColor,
                                minWidth: math.max(
                                  140.0,
                                  minBubbleWidth - 26.0,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],

                            // MESSAGE
                            SelectionArea(
                              child: Text(
                                widget.message.content,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: textColor),
                              ),
                            ),

                            const SizedBox(height: 6),

                            // BOTTOM
                            if (summaries.isEmpty)
                              MessageTime(
                                dateTime: widget.message.createdAt,
                                textColor: textColor,
                              )
                            else
                              MessageReactionTimeRow(
                                summaries: summaries,
                                maxReactionWidth: reactionAreaMaxWidth,
                                dateTime: widget.message.createdAt,
                                textColor: textColor,
                                onToggleReaction: widget.onToggleReaction,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );

          // MESSAGE ROW

          return Row(
            mainAxisAlignment: widget.isOwn
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // AVATAR
              if (!widget.isOwn) ...[
                MessageAvatar(name: displayName, avatarUrl: avatarUrl),
                const SizedBox(width: 8),
              ],

              // NAME + BUBBLE
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: widget.isOwn
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    if (!widget.isOwn)
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 4),
                        child: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    bubble,
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // PREFERRED BOTTOM WIDTH

  double _preferredReactionRowWidth(List<MessageReactionSummary> summaries) {
    if (summaries.isEmpty) {
      return 0;
    }

    var width = 0.0;

    for (var i = 0; i < summaries.length; i++) {
      if (i > 0) {
        width += 5;
      }

      width += _estimatedReactionChipWidth(summaries[i]);
    }

    // Gap до времени.
    width += 8;

    // HH:mm.
    width += 42;

    return width;
  }

  // ESTIMATED REACTION WIDTH

  double _estimatedReactionChipWidth(MessageReactionSummary summary) {
    const reactionSize = 18.0;
    const padding = 12.0;
    const reactionAvatarGap = 4.0;
    const avatarSize = 17.0;
    const avatarOverlap = 5.0;

    final visibleCount = math.min(summary.userIds.length, 3);

    double avatarWidth = 0;

    if (visibleCount > 0) {
      avatarWidth =
          avatarSize + (visibleCount - 1) * (avatarSize - avatarOverlap);
    }

    final hiddenCount = summary.userIds.length - visibleCount;

    double hiddenWidth = 0;

    if (hiddenCount > 0) {
      // SizedBox(4) + текст "+N".
      hiddenWidth = hiddenCount < 10 ? 18 : 24;
    }

    return padding +
        reactionSize +
        reactionAvatarGap +
        avatarWidth +
        hiddenWidth +
        4.0;
  }

  // REACTION SUMMARY

  List<MessageReactionSummary> _buildReactionSummaries() {
    final grouped = <String, List<RoomMessageReaction>>{};

    for (final reaction in widget.reactions) {
      grouped.putIfAbsent(reaction.reaction, () => []).add(reaction);
    }

    final result = <MessageReactionSummary>[];

    for (final entry in grouped.entries) {
      final userIds = entry.value.map((reaction) => reaction.userId).toList();

      final selectedByMe =
          widget.currentUserId != null &&
          userIds.contains(widget.currentUserId);

      result.add(
        MessageReactionSummary(
          reactionId: entry.key,
          userIds: userIds,
          selectedByMe: selectedByMe,
        ),
      );
    }

    result.sort((a, b) {
      final aIndex = ReactionCatalog.indexOf(a.reactionId);

      final bIndex = ReactionCatalog.indexOf(b.reactionId);

      if (aIndex == -1 && bIndex == -1) {
        return a.reactionId.compareTo(b.reactionId);
      }

      if (aIndex == -1) {
        return 1;
      }

      if (bIndex == -1) {
        return -1;
      }

      return aIndex.compareTo(bIndex);
    });

    return result;
  }
}
