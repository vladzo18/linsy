import 'package:linsy/core/feedback/app_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:linsy/features/profile/application/profile_store.dart';
import '../../domain/models/room_action_request.dart';
import '../controllers/action_request_controller.dart';
import '../controllers/room_state.dart';

import 'request_visuals.dart';

class IncomingRequestsPanel extends ConsumerWidget {
  const IncomingRequestsPanel({
    super.key,
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

      error: (error, stackTrace) => EmptyRequests(
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
          return const EmptyRequests(
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

                onReject: () async {
                  try {
                    await controller.rejectRequest(pending[index].id);
                  } catch (_) {
                    if (context.mounted) {
                      AppNotice.show(
                        context,
                        'Could not reject the request.',
                        kind: NoticeKind.error,
                      );
                    }
                  }
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

                    AppNotice.show(context, message, kind: NoticeKind.error);
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

// INCOMING REQUEST CARD

class _IncomingRequestCard extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    final member = roomState.members
        .where((member) => member.userId == request.userId)
        .firstOrNull;

    final userId = member?.userId ?? request.userId;

    final profile = ref.watch(profileByIdProvider(userId));

    final name = profile?.displayName ?? 'User';

    final avatarUrl = profile?.avatarUrl;

    final subtitle = requestPayloadText(request);

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
          // AVATAR
          CircleAvatar(
            radius: 20,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null ? Text(requestInitial(name)) : null,
          ),

          const SizedBox(width: 10),

          // INFO
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
                    RequestActionIcon(action: request.action, compact: true),

                    const SizedBox(width: 6),

                    Expanded(
                      child: Text(
                        requestName(request.action),
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

          // ACTIONS
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
