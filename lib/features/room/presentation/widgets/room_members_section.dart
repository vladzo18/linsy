import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/room_repository_provider.dart';
import '../../domain/models/room_member.dart';
import '../controllers/room_state.dart';

class RoomMembersSection extends ConsumerWidget {
  const RoomMembersSection({
    required this.state,
    required this.currentUserId,
    required this.roomId,
    super.key,
  });

  final RoomState state;
  final String? currentUserId;
  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (state.status) {
      case RoomStatus.loading:
      case RoomStatus.leaving:
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        );

      case RoomStatus.error:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(state.errorMessage ?? 'Failed to load room members.'),
        );

      case RoomStatus.ready:
        return _buildReady(context, ref);
    }
  }

  Widget _buildReady(BuildContext context, WidgetRef ref) {
    final currentMember = state.members
        .where((member) => member.user.id == currentUserId)
        .firstOrNull;

    final canManageRoles = currentMember?.isHost ?? false;

    if (state.members.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('No participants yet.'),
      );
    }

    return Column(
      children: [
        for (final member in state.members)
          _MemberTile(
            member: member,
            roomId: roomId,
            canManageRoles: canManageRoles,
          ),
      ],
    );
  }
}

// =====================================================================
// MEMBER
// =====================================================================

class _MemberTile extends ConsumerWidget {
  const _MemberTile({
    required this.member,
    required this.roomId,
    required this.canManageRoles,
  });

  final RoomMember member;
  final String roomId;
  final bool canManageRoles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: EdgeInsets.zero,

      leading: CircleAvatar(
        backgroundImage: member.user.avatarUrl != null
            ? NetworkImage(member.user.avatarUrl!)
            : null,

        child: member.user.avatarUrl == null
            ? Text(_initial(member.user.name))
            : null,
      ),

      title: Text(member.user.name ?? 'Linsy user'),

      subtitle: Text(_roleLabel(member.role)),

      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (member.isHost)
            const Chip(label: Text('Host'))
          else if (member.isModerator)
            const Chip(label: Text('Moderator')),

          if (canManageRoles && !member.isHost)
            PopupMenuButton<RoomMemberRole>(
              tooltip: 'Manage role',

              onSelected: (role) => _setRole(context, ref, role),

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
            ),
        ],
      ),
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
          .setMemberRole(roomId: roomId, userId: member.user.id, role: role);
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
// HELPERS
// =====================================================================

String _roleLabel(RoomMemberRole role) {
  switch (role) {
    case RoomMemberRole.host:
      return 'Host';

    case RoomMemberRole.moderator:
      return 'Moderator';

    case RoomMemberRole.member:
      return 'Member';
  }
}

String _initial(String? name) {
  if (name == null || name.isEmpty) {
    return '?';
  }

  return name.characters.first.toUpperCase();
}
