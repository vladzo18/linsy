import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../profile/application/profile_store.dart';
import '../../domain/models/room_message.dart';

import 'message_formatters.dart';

class MessageReplyPreview extends ConsumerWidget {
  const MessageReplyPreview({
    super.key,
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
// MESSAGE AVATAR

class MessageAvatar extends StatelessWidget {
  const MessageAvatar({super.key, required this.name, required this.avatarUrl});

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
          : Text(messageInitial(name), style: const TextStyle(fontSize: 12)),
    );
  }
}
