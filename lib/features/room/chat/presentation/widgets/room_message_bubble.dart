import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../profile/application/profile_store.dart';
import '../../domain/models/room_message.dart';
import '../../domain/models/room_message_reaction.dart';
import '../reactions/reaction_catalog.dart';

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

// =====================================================================
// MESSAGE
// =====================================================================

class _RoomMessageBubbleState extends ConsumerState<RoomMessageBubble> {
  final MenuController _actionsController = MenuController();

  // ===================================================================
  // ACTION MENU
  // ===================================================================

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

  // ===================================================================
  // BUILD
  // ===================================================================

  @override
  Widget build(BuildContext context) {
    // ===============================================================
    // AUTHOR PROFILE
    // ===============================================================
    //
    // Имя и аватар сообщения больше НЕ хранятся/берутся
    // из RoomMessage или RoomMember.
    //
    // Единственный источник истины:
    //
    // message.userId
    //      ↓
    // ProfileStore
    // ===============================================================

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

          // ===========================================================
          // CONTENT-BASED MIN WIDTH
          // ===========================================================

          final reactionRowWidth = _preferredReactionRowWidth(summaries);

          var preferredMinWidth = 96.0;

          if (reactionRowWidth > 0) {
            // +26 = horizontal padding bubble.
            preferredMinWidth = math.max(
              preferredMinWidth,
              reactionRowWidth + 26,
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

          const timeWidth = 42.0;
          const timeGap = 8.0;

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

                // =====================================================
                // ACTION MENU
                // =====================================================
                menuChildren: [
                  _MessageActionsPanel(
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

                // =====================================================
                // BUBBLE
                // =====================================================
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
                            // =========================================
                            // REPLY
                            // =========================================
                            if (widget.message.reply != null) ...[
                              _ReplyPreview(
                                reply: widget.message.reply!,
                                textColor: textColor,
                                minWidth: math.max(
                                  140.0,
                                  minBubbleWidth - 26.0,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],

                            // =========================================
                            // MESSAGE
                            // =========================================
                            SelectableText(
                              widget.message.content,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: textColor),
                            ),

                            const SizedBox(height: 6),

                            // =========================================
                            // BOTTOM
                            // =========================================
                            if (summaries.isEmpty)
                              _MessageTime(
                                dateTime: widget.message.createdAt,
                                textColor: textColor,
                              )
                            else
                              _ReactionTimeRow(
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

          // ===========================================================
          // MESSAGE ROW
          // ===========================================================

          return Row(
            mainAxisAlignment: widget.isOwn
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // =======================================================
              // AVATAR
              // =======================================================
              if (!widget.isOwn) ...[
                _MessageAvatar(name: displayName, avatarUrl: avatarUrl),
                const SizedBox(width: 8),
              ],

              // =======================================================
              // NAME + BUBBLE
              // =======================================================
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

  // ===================================================================
  // PREFERRED BOTTOM WIDTH
  // ===================================================================

  double _preferredReactionRowWidth(List<_ReactionSummary> summaries) {
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

  // ===================================================================
  // ESTIMATED REACTION WIDTH
  // ===================================================================

  double _estimatedReactionChipWidth(_ReactionSummary summary) {
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
        hiddenWidth;
  }

  // ===================================================================
  // REACTION SUMMARY
  // ===================================================================

  List<_ReactionSummary> _buildReactionSummaries() {
    final grouped = <String, List<RoomMessageReaction>>{};

    for (final reaction in widget.reactions) {
      grouped.putIfAbsent(reaction.reaction, () => []).add(reaction);
    }

    final result = <_ReactionSummary>[];

    for (final entry in grouped.entries) {
      final userIds = entry.value.map((reaction) => reaction.userId).toList();

      final selectedByMe =
          widget.currentUserId != null &&
          userIds.contains(widget.currentUserId);

      result.add(
        _ReactionSummary(
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

// =====================================================================
// REACTIONS + TIME
// =====================================================================

class _ReactionTimeRow extends StatelessWidget {
  const _ReactionTimeRow({
    required this.summaries,
    required this.maxReactionWidth,
    required this.dateTime,
    required this.textColor,
    required this.onToggleReaction,
  });

  final List<_ReactionSummary> summaries;

  final double maxReactionWidth;

  final DateTime dateTime;

  final Color textColor;

  final Future<void> Function(String reaction) onToggleReaction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // =============================================================
        // REACTIONS
        // =============================================================
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxReactionWidth),
          child: Wrap(
            alignment: WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 5,
            runSpacing: 4,
            children: [
              for (final summary in summaries)
                _ReactionChip(
                  summary: summary,
                  selected: summary.selectedByMe,
                  onPressed: () async {
                    await onToggleReaction(summary.reactionId);
                  },
                ),
            ],
          ),
        ),

        const Spacer(),

        const SizedBox(width: 8),

        // =============================================================
        // TIME
        // =============================================================
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(
            _formatTime(dateTime),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor.withValues(alpha: 0.55),
            ),
          ),
        ),
      ],
    );
  }
}

// =====================================================================
// TIME WITHOUT REACTIONS
// =====================================================================

class _MessageTime extends StatelessWidget {
  const _MessageTime({required this.dateTime, required this.textColor});

  final DateTime dateTime;

  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        _formatTime(dateTime),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: textColor.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

// =====================================================================
// MESSAGE ACTIONS
// =====================================================================

class _MessageActionsPanel extends StatefulWidget {
  const _MessageActionsPanel({
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
  State<_MessageActionsPanel> createState() => _MessageActionsPanelState();
}

class _MessageActionsPanelState extends State<_MessageActionsPanel> {
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

// =====================================================================
// QUICK REACTION
// =====================================================================

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
                child: _ReactionVisual(reactionId: reaction.id, size: 25),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// ACTION BUTTON
// =====================================================================

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

// =====================================================================
// REACTION GRID ITEM
// =====================================================================

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
            child: _ReactionVisual(reactionId: reaction.id, size: 27),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// REACTION SUMMARY
// =====================================================================

class _ReactionSummary {
  const _ReactionSummary({
    required this.reactionId,
    required this.userIds,
    required this.selectedByMe,
  });

  final String reactionId;

  final List<String> userIds;

  final bool selectedByMe;

  int get count => userIds.length;
}

// =====================================================================
// REACTION CHIP
// =====================================================================

class _ReactionChip extends ConsumerWidget {
  const _ReactionChip({
    required this.summary,
    required this.selected,
    required this.onPressed,
  });

  final _ReactionSummary summary;

  final bool selected;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;

    // Каждый пользователь реакции разрешается
    // через единый ProfileStore.
    //
    // profileByIdProvider сам lazy-load'ит профиль,
    // если его ещё нет в cache.

    final names = summary.userIds
        .map((id) => ref.watch(profileByIdProvider(id))?.displayName)
        .whereType<String>()
        .where((name) => name.trim().isNotEmpty)
        .join(', ');

    return Tooltip(
      message: names.isNotEmpty
          ? names
          : '${summary.count} reaction'
                '${summary.count == 1 ? '' : 's'}',
      child: Material(
        color: selected
            ? colors.primary.withValues(alpha: 0.12)
            : colors.surface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 27,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? colors.primary.withValues(alpha: 0.65)
                    : colors.outlineVariant.withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ReactionVisual(reactionId: summary.reactionId, size: 18),

                const SizedBox(width: 4),

                _ReactionUserAvatars(userIds: summary.userIds),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// REACTION AVATARS
// =====================================================================

class _ReactionUserAvatars extends ConsumerWidget {
  const _ReactionUserAvatars({required this.userIds});

  final List<String> userIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const avatarSize = 17.0;
    const overlap = 5.0;

    final visible = userIds.take(3).toList();

    final hiddenCount = userIds.length - visible.length;

    final avatarAreaWidth = visible.isEmpty
        ? 0.0
        : avatarSize + (visible.length - 1) * (avatarSize - overlap);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (visible.isNotEmpty)
          SizedBox(
            width: avatarAreaWidth,
            height: avatarSize,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (var index = 0; index < visible.length; index++)
                  Positioned(
                    left: index * (avatarSize - overlap),
                    child: _ProfileReactionAvatar(
                      userId: visible[index],
                      size: avatarSize,
                    ),
                  ),
              ],
            ),
          ),

        if (hiddenCount > 0) ...[
          const SizedBox(width: 4),

          Text(
            '+$hiddenCount',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}

// =====================================================================
// PROFILE REACTION AVATAR
// =====================================================================

class _ProfileReactionAvatar extends ConsumerWidget {
  const _ProfileReactionAvatar({required this.userId, required this.size});

  final String userId;

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileByIdProvider(userId));

    return _MiniReactionAvatar(
      size: size,
      avatarUrl: profile?.avatarUrl,
      name: profile?.displayName,
    );
  }
}

// =====================================================================
// MINI AVATAR
// =====================================================================

class _MiniReactionAvatar extends StatelessWidget {
  const _MiniReactionAvatar({
    required this.size,
    required this.avatarUrl,
    required this.name,
  });

  final double size;

  final String? avatarUrl;

  final String? name;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;

    return Tooltip(
      message: name?.trim().isNotEmpty == true ? name! : 'Linsy user',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.surface,
          border: Border.all(color: colors.surface, width: 1.4),
        ),
        child: ClipOval(
          child: hasAvatar
              ? Image.network(
                  avatarUrl!,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _MiniAvatarFallback(name: name);
                  },
                )
              : _MiniAvatarFallback(name: name),
        ),
      ),
    );
  }
}

// =====================================================================
// MINI AVATAR FALLBACK
// =====================================================================

class _MiniAvatarFallback extends StatelessWidget {
  const _MiniAvatarFallback({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ColoredBox(
      color: colors.secondaryContainer,
      child: Center(
        child: Text(
          _initial(name),
          style: TextStyle(
            fontSize: 8,
            height: 1,
            fontWeight: FontWeight.w700,
            color: colors.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// REACTION VISUAL
// =====================================================================

class _ReactionVisual extends StatelessWidget {
  const _ReactionVisual({required this.reactionId, required this.size});

  final String reactionId;

  final double size;

  @override
  Widget build(BuildContext context) {
    final definition = ReactionCatalog.find(reactionId);

    final assetPath = definition?.assetPath;

    if (assetPath != null) {
      return Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Text('❔', style: TextStyle(fontSize: size));
        },
      );
    }

    return Text(
      definition?.emoji ?? '❔',
      style: TextStyle(fontSize: size, height: 1),
    );
  }
}

// =====================================================================
// REPLY PREVIEW
// =====================================================================

class _ReplyPreview extends ConsumerWidget {
  const _ReplyPreview({
    required this.reply,
    required this.textColor,
    required this.minWidth,
  });

  final RoomMessageReplyPreview reply;

  final Color textColor;

  final double minWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileByIdProvider(reply.userId));

    final profileName = profile?.displayName?.trim();

    final displayName = profileName != null && profileName.isNotEmpty
        ? profileName
        : 'Linsy user';

    final colors = Theme.of(context).colorScheme;

    return Container(
      constraints: BoxConstraints(minWidth: minWidth),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(9),
        border: Border(left: BorderSide(color: colors.primary, width: 3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 2),

          Text(
            reply.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: textColor.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}
// =====================================================================
// MESSAGE AVATAR
// =====================================================================

class _MessageAvatar extends StatelessWidget {
  const _MessageAvatar({required this.name, required this.avatarUrl});

  final String name;

  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;

    return CircleAvatar(
      radius: 16,
      backgroundImage: hasAvatar ? NetworkImage(avatarUrl!) : null,
      child: hasAvatar
          ? null
          : Text(_initial(name), style: const TextStyle(fontSize: 12)),
    );
  }
}

// =====================================================================
// HELPERS
// =====================================================================

String _initial(String? name) {
  final normalized = name?.trim() ?? '';

  if (normalized.isEmpty) {
    return '?';
  }

  return normalized.characters.first.toUpperCase();
}

String _formatTime(DateTime dateTime) {
  final local = dateTime.toLocal();

  final hours = local.hour.toString().padLeft(2, '0');

  final minutes = local.minute.toString().padLeft(2, '0');

  return '$hours:$minutes';
}
