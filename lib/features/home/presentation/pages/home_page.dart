import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:linsy/features/room/application/room_membership_service.dart';
import 'package:linsy/features/settings/presentation/pages/settings_page.dart';

import '../../../../app/session/app_session_controller.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../room/data/providers/room_repository_provider.dart';
import '../controllers/home_controller.dart';
import '../controllers/home_state.dart';
import '../../../profile/application/profile_store.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final homeAsync = ref.watch(homeControllerProvider);

    final user = authState.user;

    final profile = user == null
        ? null
        : ref.watch(profileByIdProvider(user.id));

    final profileName = profile?.displayName?.trim();

    final displayName = profileName != null && profileName.isNotEmpty
        ? profileName
        : user?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.graphic_eq_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            const Text('Linsy'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const SettingsPage(),
                ),
              );
            },
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
          IconButton(
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).signOut();
            },
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
          ),
          const SizedBox(width: 8),
        ],
      ),

      // ===============================================================
      // BODY
      // ===============================================================
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(homeControllerProvider.notifier).refresh();
          },

          // -----------------------------------------------------------
          // Important:
          //
          // ListView itself occupies the full window width.
          // The content is centered INSIDE it.
          //
          // So scrollbars stay at the window edge.
          // -----------------------------------------------------------
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // =================================================
                      // WELCOME
                      // =================================================
                      _WelcomeSection(userName: displayName),

                      const SizedBox(height: 24),

                      // =================================================
                      // ACTIONS
                      // =================================================
                      const _RoomActions(),

                      const SizedBox(height: 34),

                      // =================================================
                      // ROOMS HEADER
                      // =================================================
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Rooms',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Refresh rooms',
                            onPressed: () {
                              ref
                                  .read(homeControllerProvider.notifier)
                                  .refresh();
                            },
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // =================================================
                      // ROOMS
                      // =================================================
                      homeAsync.when(
                        loading: () => const _RoomsLoading(),

                        error: (error, stackTrace) {
                          return _ErrorCard(
                            onRetry: () {
                              ref
                                  .read(homeControllerProvider.notifier)
                                  .refresh();
                            },
                          );
                        },

                        data: (state) {
                          return _RoomsSection(state: state);
                        },
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// WELCOME
// =====================================================================

class _WelcomeSection extends StatelessWidget {
  const _WelcomeSection({required this.userName});

  final String? userName;

  @override
  Widget build(BuildContext context) {
    final cleanName = userName?.trim();

    final greeting = cleanName == null || cleanName.isEmpty
        ? 'Welcome back'
        : 'Welcome back, $cleanName';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'Listen together, wherever you are.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// =====================================================================
// ROOM ACTIONS
// =====================================================================

class _RoomActions extends StatelessWidget {
  const _RoomActions();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 620;

        final create = _HomeActionCard(
          icon: Icons.add_rounded,
          title: 'Create room',
          description: 'Start a new listening room.',
          filled: true,
          onPressed: () {
            context.push('/room/create');
          },
        );

        final join = _HomeActionCard(
          icon: Icons.login_rounded,
          title: 'Join room',
          description: 'Enter a room using its code.',
          filled: false,
          onPressed: () {
            context.push('/room/join');
          },
        );

        if (!wide) {
          return Column(children: [create, const SizedBox(height: 10), join]);
        }

        return Row(
          children: [
            Expanded(child: create),
            const SizedBox(width: 12),
            Expanded(child: join),
          ],
        );
      },
    );
  }
}

class _HomeActionCard extends StatelessWidget {
  const _HomeActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.filled,
    required this.onPressed,
  });

  final IconData icon;

  final String title;
  final String description;

  final bool filled;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: filled
          ? colors.primaryContainer.withValues(alpha: 0.72)
          : colors.surfaceContainerHighest.withValues(alpha: 0.38),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: filled ? colors.primary : colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: filled
                      ? colors.onPrimary
                      : colors.onSecondaryContainer,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Icon(Icons.arrow_forward_rounded, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// ROOMS
// =====================================================================

class _RoomsSection extends StatelessWidget {
  const _RoomsSection({required this.state});

  final HomeState state;

  @override
  Widget build(BuildContext context) {
    if (state.status == HomeStatus.error) {
      return _ErrorCard(message: state.errorMessage, onRetry: () {});
    }

    if (state.rooms.isEmpty) {
      return const _EmptyRoomsCard();
    }

    return Column(
      children: [
        for (var i = 0; i < state.rooms.length; i++) ...[
          _RoomCard(item: state.rooms[i]),
          if (i != state.rooms.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

// =====================================================================
// ROOM CARD
// =====================================================================

class _RoomCard extends ConsumerStatefulWidget {
  const _RoomCard({required this.item});

  final HomeRoomItem item;

  @override
  ConsumerState<_RoomCard> createState() => _RoomCardState();
}

class _RoomCardState extends ConsumerState<_RoomCard> {
  bool _isRejoining = false;

  bool _isDeleting = false;

  // ===================================================================
  // REJOIN
  // ===================================================================

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

  // ===================================================================
  // DELETE
  // ===================================================================

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

  // ===================================================================
  // MESSAGE
  // ===================================================================

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ===================================================================
  // BUILD
  // ===================================================================

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

    return Card(
      margin: EdgeInsets.zero,
      color: cardColor,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
        child: Row(
          children: [
            // =========================================================
            // ICON
            // =========================================================
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isOwned
                    ? Icons.workspace_premium_rounded
                    : Icons.history_rounded,
                color: iconColor,
              ),
            ),

            const SizedBox(width: 14),

            // =========================================================
            // INFO
            // =========================================================
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          room.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),

                      const SizedBox(width: 10),

                      _RoomBadge(owned: isOwned),
                    ],
                  ),

                  const SizedBox(height: 5),

                  Row(
                    children: [
                      Text(
                        'Code',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
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
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 16),

            // =========================================================
            // ACTIONS
            // =========================================================
            if (_isRejoining)
              const SizedBox(
                width: 40,
                height: 40,
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              FilledButton.tonalIcon(
                onPressed: isBusy ? null : _rejoin,
                icon: const Icon(Icons.login_rounded, size: 18),
                label: const Text('Rejoin'),
              ),

            if (isOwned) ...[
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Delete room',
                onPressed: isBusy ? null : _deleteRoom,
                icon: _isDeleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.delete_outline_rounded, color: colors.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// ROOM BADGE
// =====================================================================

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

// =====================================================================
// LOADING
// =====================================================================

class _RoomsLoading extends StatelessWidget {
  const _RoomsLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

// =====================================================================
// EMPTY
// =====================================================================

class _EmptyRoomsCard extends StatelessWidget {
  const _EmptyRoomsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          children: [
            Icon(
              Icons.meeting_room_outlined,
              size: 44,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'No rooms yet.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 5),
            Text(
              'Create a room or join one to see it here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// ERROR
// =====================================================================

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({this.message, required this.onRetry});

  final String? message;

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 42,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 10),
            Text(
              message ?? 'Failed to load your rooms.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// RECENT TIME
// =====================================================================

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
