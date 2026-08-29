import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:linsy/features/profile/application/profile_store.dart';

import '../../data/providers/room_repository_provider.dart';
import '../../domain/models/room_member.dart';
import '../controllers/room_state.dart';

class RoomParticipantsBar extends ConsumerWidget {
  const RoomParticipantsBar({
    required this.roomId,
    required this.roomState,
    required this.currentUserId,
    super.key,
  });

  final String roomId;
  final RoomState roomState;
  final String? currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (roomState.status != RoomStatus.ready) {
      return const SizedBox.shrink();
    }

    final currentMember = roomState.members
        .where((member) => member.userId == currentUserId)
        .firstOrNull;

    final canManageRoles = currentMember?.isHost ?? false;

    if (roomState.members.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 64,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          itemCount: roomState.members.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final member = roomState.members[index];

            return _ParticipantPill(
              roomId: roomId,
              member: member,
              canManageRole: canManageRoles && !member.isHost,
            );
          },
        ),
      ),
    );
  }
}

// =====================================================================
// PARTICIPANT
// =====================================================================

class _ParticipantPill extends ConsumerWidget {
  const _ParticipantPill({
    required this.roomId,
    required this.member,
    required this.canManageRole,
  });

  final String roomId;
  final RoomMember member;
  final bool canManageRole;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileByIdProvider(member.userId));
    final displayName = profile?.displayName ?? 'User';
    final avatarUrl = profile?.avatarUrl;

    final pill = Container(
      padding: const EdgeInsets.fromLTRB(6, 5, 10, 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 17,
            backgroundImage: avatarUrl != null
                ? NetworkImage(avatarUrl)
                : null,
            child: avatarUrl == null
                ? Text(_initial(displayName))
                : null,
          ),

          const SizedBox(width: 8),

          Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge,
          ),

          if (member.isHost) ...[
            const SizedBox(width: 7),
            const _RoleBadge(label: 'HOST'),
          ] else if (member.isModerator) ...[
            const SizedBox(width: 7),
            const _RoleBadge(label: 'MOD'),
          ],

          if (canManageRole) ...[
            const SizedBox(width: 3),
            const Icon(Icons.arrow_drop_down_rounded, size: 18),
          ],
        ],
      ),
    );

    if (!canManageRole) {
      return pill;
    }

    return PopupMenuButton<RoomMemberRole>(
      tooltip: 'Manage role',
      onSelected: (role) {
        _setRole(context, ref, role);
      },
      itemBuilder: (context) => [
        if (!member.isModerator)
          const PopupMenuItem(
            value: RoomMemberRole.moderator,
            child: Text('Make moderator'),
          ),

        if (member.isModerator)
          const PopupMenuItem(
            value: RoomMemberRole.member,
            child: Text('Remove moderator'),
          ),
      ],
      child: pill,
    );
  }

  Future<void> _setRole(
    BuildContext context,
    WidgetRef ref,
    RoomMemberRole role,
  ) async {
    try {
      await ref
          .read(roomRepositoryProvider)
          .setMemberRole(roomId: roomId, userId: member.userId, role: role);
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Failed to change role: '
              '$error',
            ),
          ),
        );
    }
  }
}

// =====================================================================
// ROLE
// =====================================================================

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// =====================================================================
// HELPERS
// =====================================================================

String _initial(String? name) {
  if (name == null || name.isEmpty) {
    return '?';
  }

  return name.characters.first.toUpperCase();
}
