import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:linsy/features/room/application/room_membership_service.dart';

import '../../../../app/session/app_session_controller.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../room/data/providers/room_repository_provider.dart';
import '../controllers/home_controller.dart';
import '../controllers/home_state.dart';

class HomeRoomCard extends ConsumerStatefulWidget {
  const HomeRoomCard({super.key, required this.item});

  final HomeRoomItem item;

  @override
  ConsumerState<HomeRoomCard> createState() => _RoomCardState();
}

class _RoomCardState extends ConsumerState<HomeRoomCard> {
  bool _isRejoining = false;

  bool _isDeleting = false;

  // REJOIN

  Future<void> _rejoin() async {
    if (_isRejoining || _isDeleting) {
      return;
    }

    final user = ref.read(authControllerProvider).user;

    if (user == null) {
      _showMessage('You must be signed in to rejoin a room.');

      return;
    }

    setState(() {
      _isRejoining = true;
    });

    try {
      await ref
          .read(roomMembershipServiceProvider)
          .joinRoom(roomId: widget.item.room.id, userId: user.id);

      ref
          .read(appSessionControllerProvider.notifier)
          .enterRoom(widget.item.room.id);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('You may already be in another room. Leave it first.');
    } finally {
      if (mounted) {
        setState(() {
          _isRejoining = false;
        });
      }
    }
  }

  // DELETE

  Future<void> _deleteRoom() async {
    if (!widget.item.isOwned || _isRejoining || _isDeleting) {
      return;
    }

    final room = widget.item.room;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete room?'),
          content: Text(
            'Delete "${room.name}" permanently? '
            'All participants will be disconnected.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    final user = ref.read(authControllerProvider).user;

    if (user == null) {
      _showMessage('You must be signed in to delete a room.');

      return;
    }

    setState(() {
      _isDeleting = true;
    });

    try {
      await ref
          .read(roomRepositoryProvider)
          .deleteRoom(roomId: room.id, userId: user.id);

      ref.invalidate(homeControllerProvider);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('Failed to delete the room.');
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  // MESSAGE

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // BUILD

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    final room = item.room;

    final isOwned = item.isOwned;

    final isBusy = _isRejoining || _isDeleting;

    final colors = Theme.of(context).colorScheme;

    final cardColor = isOwned
        ? colors.primaryContainer.withValues(alpha: 0.34)
        : colors.surfaceContainerHighest.withValues(alpha: 0.30);

    final iconBackground = isOwned
        ? colors.primaryContainer
        : colors.surfaceContainerHighest;

    final iconColor = isOwned
        ? colors.onPrimaryContainer
        : colors.onSurfaceVariant;

    Widget buildRoomIcon() {
      return Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: iconBackground,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          isOwned ? Icons.workspace_premium_rounded : Icons.history_rounded,
          color: iconColor,
        ),
      );
    }

    Widget buildRoomInfo() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  room.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              _RoomBadge(owned: isOwned),
            ],
          ),

          const SizedBox(height: 5),

          Row(
            children: [
              Text(
                'Code',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),

              const SizedBox(width: 8),

              SelectableText(
                room.roomCode,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),

          if (!isOwned && item.lastVisitedAt != null) ...[
            const SizedBox(height: 3),
            Text(
              _recentLabel(item.lastVisitedAt!),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ],
      );
    }

    Widget buildRejoinButton({bool expanded = false}) {
      if (_isRejoining) {
        return SizedBox(
          height: 40,
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      }

      final button = FilledButton.tonalIcon(
        onPressed: isBusy ? null : _rejoin,
        icon: const Icon(Icons.login_rounded, size: 18),
        label: const Text('Rejoin'),
      );

      if (!expanded) {
        return button;
      }

      return SizedBox(width: double.infinity, child: button);
    }

    Widget buildDeleteButton() {
      return IconButton.filledTonal(
        tooltip: 'Delete room',
        onPressed: isBusy ? null : _deleteRoom,
        icon: _isDeleting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(Icons.delete_outline_rounded, color: colors.error),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;

        return Card(
          margin: EdgeInsets.zero,
          color: cardColor,
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 14 : 18,
              16,
              compact ? 12 : 14,
              16,
            ),
            child: compact
                ? Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          buildRoomIcon(),

                          const SizedBox(width: 12),

                          Expanded(child: buildRoomInfo()),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(child: buildRejoinButton(expanded: true)),

                          if (isOwned) ...[
                            const SizedBox(width: 8),
                            buildDeleteButton(),
                          ],
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      buildRoomIcon(),

                      const SizedBox(width: 14),

                      Expanded(child: buildRoomInfo()),

                      const SizedBox(width: 16),

                      buildRejoinButton(),

                      if (isOwned) ...[
                        const SizedBox(width: 4),
                        buildDeleteButton(),
                      ],
                    ],
                  ),
          ),
        );
      },
    );
  }
}

// ROOM BADGE

class _RoomBadge extends StatelessWidget {
  const _RoomBadge({required this.owned});

  final bool owned;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: owned ? colors.primary : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        owned ? 'Owner' : 'Recent',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: owned ? colors.onPrimary : colors.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// LOADING

String _recentLabel(DateTime value) {
  final local = value.toLocal();

  final now = DateTime.now();

  final today = DateTime(now.year, now.month, now.day);

  final date = DateTime(local.year, local.month, local.day);

  final difference = today.difference(date).inDays;

  final time =
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';

  if (difference == 0) {
    return 'Visited today at $time';
  }

  if (difference == 1) {
    return 'Visited yesterday at $time';
  }

  return 'Visited '
      '${local.day.toString().padLeft(2, '0')}.'
      '${local.month.toString().padLeft(2, '0')}.'
      '${local.year}';
}
