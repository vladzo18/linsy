import 'package:linsy/core/feedback/app_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/room_action_request.dart';
import '../controllers/action_request_controller.dart';

import 'request_visuals.dart';

class MemberRequestsPanel extends ConsumerWidget {
  const MemberRequestsPanel({
    super.key,
    required this.roomId,
    required this.requestsState,
    required this.currentUserId,
  });

  final String roomId;

  final AsyncValue<List<RoomActionRequest>> requestsState;

  final String currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(
      actionRequestControllerProvider(roomId).notifier,
    );

    final pending =
        requestsState.value
            ?.where(
              (request) =>
                  request.userId == currentUserId &&
                  request.status == RoomActionRequestStatus.pending,
            )
            .toList() ??
        const <RoomActionRequest>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                'Use the player or Add track to send a request. Pending requests appear here.',
          )
        else
          Column(
            children: [
              for (var index = 0; index < pending.length; index++) ...[
                _OwnRequestCard(
                  request: pending[index],
                  onCancel: () async {
                    try {
                      await controller.cancelRequest(pending[index].id);
                    } catch (_) {
                      if (context.mounted) {
                        AppNotice.show(
                          context,
                          'Could not cancel the request.',
                          kind: NoticeKind.error,
                        );
                      }
                    }
                  },
                ),

                if (index != pending.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
      ],
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
