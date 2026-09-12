import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../profile/application/profile_store.dart';

import 'message_formatters.dart';
import 'message_reaction_visual.dart';

class MessageReactionSummary {
  const MessageReactionSummary({
    required this.reactionId,
    required this.userIds,
    required this.selectedByMe,
  });

  final String reactionId;

  final List<String> userIds;

  final bool selectedByMe;

  int get count => userIds.length;
}

// REACTION CHIP

class MessageReactionChip extends ConsumerWidget {
  const MessageReactionChip({
    super.key,
    required this.summary,
    required this.selected,
    required this.onPressed,
  });

  final MessageReactionSummary summary;

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
                MessageReactionVisual(reactionId: summary.reactionId, size: 18),

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

// REACTION AVATARS

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

// PROFILE REACTION AVATAR

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

// MINI AVATAR

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

// MINI AVATAR FALLBACK

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
          messageInitial(name),
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
