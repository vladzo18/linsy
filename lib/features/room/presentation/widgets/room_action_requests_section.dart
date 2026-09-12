import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/action_request_controller.dart';
import '../controllers/room_state.dart';

import 'request_member_panel.dart';
import 'request_incoming_panel.dart';

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
        .where((member) => member.userId == currentUserId)
        .firstOrNull;

    if (currentMember == null) {
      return const SizedBox.shrink();
    }

    final requestsState = ref.watch(actionRequestControllerProvider(roomId));

    // HOST / MODERATOR

    if (currentMember.canControlPlayback) {
      return IncomingRequestsPanel(
        roomId: roomId,
        roomState: roomState,
        requestsState: requestsState,
      );
    }

    // MEMBER

    return MemberRequestsPanel(
      roomId: roomId,
      requestsState: requestsState,
      currentUserId: currentUserId!,
    );
  }
}
