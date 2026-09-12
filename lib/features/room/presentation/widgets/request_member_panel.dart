import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/room_action_request.dart';
import '../controllers/action_request_controller.dart';
import 'track_search_dialog.dart';

import 'request_visuals.dart';

class MemberRequestsPanel extends ConsumerWidget {
  const MemberRequestsPanel({
    super.key,
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
        // CREATE REQUEST
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

        // OWN PENDING
        if (requestsState.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (pending.isEmpty)
          const EmptyRequests(
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

// MEMBER ACTIONS

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

// OWN REQUEST CARD

class _OwnRequestCard extends StatelessWidget {
  const _OwnRequestCard({required this.request, required this.onCancel});

  final RoomActionRequest request;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final subtitle = requestPayloadText(request);

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
          // ACTION
          RequestActionIcon(action: request.action),

          const SizedBox(width: 10),

          // INFO
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  requestName(request.action),
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

          // STATUS
          const RequestStatusBadge(label: 'PENDING'),

          // CANCEL
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
