import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:linsy/core/feedback/app_dialog.dart';
import 'package:linsy/core/feedback/app_notice.dart';
import '../../domain/models/room_action_request.dart';
import '../controllers/action_request_controller.dart';
import 'request_visuals.dart';

final _pendingDialogs = Expando<bool>();

Future<void> confirmRoomRequest(
  BuildContext context,
  WidgetRef ref, {
  required String roomId,
  required RoomAction action,
  Map<String, dynamic>? payload,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  if (_pendingDialogs[navigator] == true) return;
  _pendingDialogs[navigator] = true;
  try {
    final description = switch (action) {
      RoomAction.play => 'Ask the host or a moderator to start playback?',
      RoomAction.pause => 'Ask the host or a moderator to pause playback?',
      RoomAction.next => 'Ask the host or a moderator to play the next track?',
      RoomAction.seek =>
        'Ask to move playback to ${formatRequestTime((payload?['position_ms'] as int?) ?? 0)}?',
      RoomAction.addTrack =>
        'Ask to add “${payload?['title'] ?? payload?['track_id'] ?? 'this track'}” to the queue?',
    };
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Request ${requestName(action).toLowerCase()}',
      message: description,
      confirmLabel: 'Send request',
      icon: requestActionIcon(action),
    );
    if (!confirmed || !context.mounted) return;
    await ref
        .read(actionRequestControllerProvider(roomId).notifier)
        .createRequest(action: action, payload: payload);
    if (context.mounted) {
      AppNotice.show(
        context,
        'Request sent to the host and moderators.',
        kind: NoticeKind.success,
      );
    }
  } catch (_) {
    if (context.mounted) {
      AppNotice.show(
        context,
        'Could not send the request. Please try again.',
        kind: NoticeKind.error,
      );
    }
  } finally {
    _pendingDialogs[navigator] = false;
  }
}
