import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/room_action_request.dart';
import '../controllers/action_request_controller.dart';
import '../controllers/room_state.dart';
import '../providers/playback_position_provider.dart';
import 'track_search_dialog.dart';

class RoomActionRequestsSection extends ConsumerWidget {
  const RoomActionRequestsSection({
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
    if (roomState.status != RoomStatus.ready || currentUserId == null) {
      return const SizedBox.shrink();
    }

    final currentMember = roomState.members
        .where((member) => member.user.id == currentUserId)
        .firstOrNull;

    if (currentMember == null) {
      return const SizedBox.shrink();
    }

    final requestsState = ref.watch(actionRequestControllerProvider(roomId));

    // =============================================================
    // HOST / MODERATOR
    // =============================================================

    if (currentMember.canControlPlayback) {
      return _IncomingRequests(
        roomId: roomId,
        roomState: roomState,
        requestsState: requestsState,
      );
    }

    // =============================================================
    // MEMBER
    // =============================================================

    final livePositionMs =
        ref.watch(playbackPositionProvider(roomId)).value ?? 0;

    return _MemberRequests(
      roomId: roomId,
      requestsState: requestsState,
      playbackPositionMs: livePositionMs,
    );
  }
}

// =====================================================================
// MEMBER
// =====================================================================

class _MemberRequests extends ConsumerWidget {
  const _MemberRequests({
    required this.roomId,
    required this.requestsState,
    required this.playbackPositionMs,
  });

  final String roomId;

  final AsyncValue<List<RoomActionRequest>> requestsState;

  final int playbackPositionMs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(
      actionRequestControllerProvider(roomId).notifier,
    );

    final pending =
        requestsState.value
            ?.where(
              (request) => request.status == RoomActionRequestStatus.pending,
            )
            .toList() ??
        const <RoomActionRequest>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // =========================================================
        // CREATE REQUEST
        // =========================================================
        _RequestActions(
          onPlay: () {
            controller.createRequest(action: RoomAction.play);
          },
          onPause: () {
            controller.createRequest(action: RoomAction.pause);
          },
          onSeek: () {
            controller.requestSeek(playbackPositionMs + 10000);
          },
          onTrack: () => _requestTrack(context, controller),
        ),

        const SizedBox(height: 18),

        // =========================================================
        // OWN PENDING
        // =========================================================
        if (requestsState.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (pending.isEmpty)
          const _EmptyRequests(
            title: 'No pending requests',
            subtitle:
                'Requests you send will appear here until they are resolved.',
          )
        else
          Column(
            children: [
              for (var index = 0; index < pending.length; index++) ...[
                _OwnRequestCard(
                  request: pending[index],
                  onCancel: () {
                    controller.cancelRequest(pending[index].id);
                  },
                ),

                if (index != pending.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
      ],
    );
  }

  Future<void> _requestTrack(
    BuildContext context,
    ActionRequestController controller,
  ) async {
    final track = await showTrackSearchDialog(context);

    if (track == null) {
      return;
    }

    await controller.createRequest(
      action: RoomAction.addTrack,
      payload: {
        'track_id': track.trackId,
        'title': track.title,
        'thumbnail_url': track.thumbnailUrl,
        'duration_ms': track.durationMs,
        'source': track.source,
      },
    );
  }
}

// =====================================================================
// MEMBER ACTIONS
// =====================================================================

class _RequestActions extends StatelessWidget {
  const _RequestActions({
    required this.onPlay,
    required this.onPause,
    required this.onSeek,
    required this.onTrack,
  });

  final VoidCallback onPlay;
  final VoidCallback onPause;
  final VoidCallback onSeek;
  final VoidCallback onTrack;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        _RequestActionButton(
          icon: Icons.play_arrow_rounded,
          label: 'Play',
          onPressed: onPlay,
        ),

        _RequestActionButton(
          icon: Icons.pause_rounded,
          label: 'Pause',
          onPressed: onPause,
        ),

        _RequestActionButton(
          icon: Icons.forward_10_rounded,
          label: '+10s',
          onPressed: onSeek,
        ),

        _RequestActionButton(
          icon: Icons.add_to_queue_rounded,
          label: 'Track',
          onPressed: onTrack,
        ),
      ],
    );
  }
}

class _RequestActionButton extends StatelessWidget {
  const _RequestActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon, size: 19),
      label: Text(label),
    );
  }
}

// =====================================================================
// OWN REQUEST CARD
// =====================================================================

class _OwnRequestCard extends StatelessWidget {
  const _OwnRequestCard({required this.request, required this.onCancel});

  final RoomActionRequest request;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final subtitle = _requestPayloadText(request);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          // =======================================================
          // ACTION
          // =======================================================
          _ActionIcon(action: request.action),

          const SizedBox(width: 10),

          // =======================================================
          // INFO
          // =======================================================
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _requestName(request.action),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),

                if (subtitle != null) ...[
                  const SizedBox(height: 2),

                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 8),

          // =======================================================
          // STATUS
          // =======================================================
          const _StatusBadge(label: 'PENDING'),

          // =======================================================
          // CANCEL
          // =======================================================
          IconButton(
            tooltip: 'Cancel request',
            visualDensity: VisualDensity.compact,
            onPressed: onCancel,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// HOST / MODERATOR
// =====================================================================

class _IncomingRequests extends ConsumerWidget {
  const _IncomingRequests({
    required this.roomId,
    required this.roomState,
    required this.requestsState,
  });

  final String roomId;
  final RoomState roomState;

  final AsyncValue<List<RoomActionRequest>> requestsState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(
      actionRequestControllerProvider(roomId).notifier,
    );

    return requestsState.when(
      loading: () => const Center(child: CircularProgressIndicator()),

      error: (error, stackTrace) => _EmptyRequests(
        title: 'Failed to load requests',
        subtitle: '$error',
        error: true,
      ),

      data: (requests) {
        final pending = requests
            .where(
              (request) => request.status == RoomActionRequestStatus.pending,
            )
            .toList();

        if (pending.isEmpty) {
          return const _EmptyRequests(
            title: 'No pending requests',
            subtitle: 'New member requests will appear here.',
          );
        }

        return Column(
          children: [
            for (var index = 0; index < pending.length; index++) ...[
              _IncomingRequestCard(
                request: pending[index],
                roomState: roomState,

                onReject: () {
                  controller.rejectRequest(pending[index].id);
                },

                onApprove: () async {
                  try {
                    await controller.approveRequest(pending[index]);
                  } catch (error) {
                    if (!context.mounted) {
                      return;
                    }

                    var message = 'Failed to approve request.';

                    if (error.toString().contains('Queue is empty')) {
                      message = 'Queue is empty.';
                    }

                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(content: Text(message)));
                  }
                },
              ),

              if (index != pending.length - 1) const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

// =====================================================================
// INCOMING REQUEST CARD
// =====================================================================

class _IncomingRequestCard extends StatelessWidget {
  const _IncomingRequestCard({
    required this.request,
    required this.roomState,
    required this.onReject,
    required this.onApprove,
  });

  final RoomActionRequest request;
  final RoomState roomState;

  final VoidCallback onReject;
  final Future<void> Function() onApprove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final member = roomState.members
        .where((member) => member.user.id == request.userId)
        .firstOrNull;

    final name = member?.user.name ?? 'Linsy user';

    final avatarUrl = member?.user.avatarUrl;

    final subtitle = _requestPayloadText(request);

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          // =======================================================
          // AVATAR
          // =======================================================
          CircleAvatar(
            radius: 20,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null ? Text(_initial(name)) : null,
          ),

          const SizedBox(width: 10),

          // =======================================================
          // INFO
          // =======================================================
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 4),

                Row(
                  children: [
                    _ActionIcon(action: request.action, compact: true),

                    const SizedBox(width: 6),

                    Expanded(
                      child: Text(
                        _requestName(request.action),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),

                if (subtitle != null) ...[
                  const SizedBox(height: 3),

                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 8),

          // =======================================================
          // ACTIONS
          // =======================================================
          Tooltip(
            message: 'Reject',
            child: IconButton.outlined(
              visualDensity: VisualDensity.compact,
              onPressed: onReject,
              icon: const Icon(Icons.close_rounded),
            ),
          ),

          const SizedBox(width: 4),

          Tooltip(
            message: 'Approve',
            child: IconButton.filledTonal(
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                await onApprove();
              },
              icon: const Icon(Icons.check_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// ACTION ICON
// =====================================================================

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({required this.action, this.compact = false});

  final RoomAction action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final size = compact ? 26.0 : 36.0;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(compact ? 8 : 10),
      ),
      child: Icon(
        _actionIcon(action),
        size: compact ? 16 : 20,
        color: colorScheme.onPrimaryContainer,
      ),
    );
  }
}

// =====================================================================
// STATUS
// =====================================================================

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onSecondaryContainer,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// =====================================================================
// EMPTY
// =====================================================================

class _EmptyRequests extends StatelessWidget {
  const _EmptyRequests({
    required this.title,
    required this.subtitle,
    this.error = false,
  });

  final String title;
  final String subtitle;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              error ? Icons.error_outline : Icons.notifications_none_rounded,
              size: 40,
              color: error ? colorScheme.error : colorScheme.onSurfaceVariant,
            ),

            const SizedBox(height: 10),

            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),

            const SizedBox(height: 4),

            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// HELPERS
// =====================================================================

IconData _actionIcon(RoomAction action) {
  switch (action) {
    case RoomAction.play:
      return Icons.play_arrow_rounded;

    case RoomAction.pause:
      return Icons.pause_rounded;

    case RoomAction.seek:
      return Icons.fast_forward_rounded;

    case RoomAction.next:
      return Icons.skip_next_rounded;

    case RoomAction.addTrack:
      return Icons.add_to_queue_rounded;
  }
}

String _requestName(RoomAction action) {
  switch (action) {
    case RoomAction.play:
      return 'Play';

    case RoomAction.pause:
      return 'Pause';

    case RoomAction.seek:
      return 'Seek';

    case RoomAction.next:
      return 'Next track';

    case RoomAction.addTrack:
      return 'Add track';
  }
}

String? _requestPayloadText(RoomActionRequest request) {
  if (request.action == RoomAction.seek) {
    final position = request.payload?['position_ms'];

    if (position is num) {
      return _formatTime(position.toInt());
    }
  }

  if (request.action == RoomAction.addTrack) {
    final title = request.payload?['title'];

    if (title is String && title.isNotEmpty) {
      return title;
    }

    final trackId = request.payload?['track_id'];

    if (trackId is String && trackId.isNotEmpty) {
      return trackId;
    }
  }

  return null;
}

String _initial(String name) {
  if (name.isEmpty) {
    return '?';
  }

  return name.characters.first.toUpperCase();
}

String _formatTime(int milliseconds) {
  final totalSeconds = milliseconds ~/ 1000;

  final hours = totalSeconds ~/ 3600;

  final minutes = (totalSeconds % 3600) ~/ 60;

  final seconds = totalSeconds % 60;

  if (hours > 0) {
    return '$hours:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  return '$minutes:'
      '${seconds.toString().padLeft(2, '0')}';
}
