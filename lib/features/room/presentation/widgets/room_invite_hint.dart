import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:linsy/core/feedback/app_dialog.dart';
import 'package:linsy/core/feedback/app_notice.dart';
import '../controllers/room_state.dart';

/// Owned by the room session so replacing its UI for PiP cannot reset the hint.
class RoomInviteSession {
  bool shown = false;
  bool? eligibleOnEntry;
}

class RoomInviteHint extends StatefulWidget {
  const RoomInviteHint({
    required this.roomId,
    required this.roomState,
    required this.roomCode,
    required this.currentUserId,
    required this.child,
    this.session,
    super.key,
  });
  final String roomId;
  final RoomState roomState;
  final String? roomCode;
  final String? currentUserId;
  final Widget child;
  final RoomInviteSession? session;
  @override
  State<RoomInviteHint> createState() => _RoomInviteHintState();
}

class _RoomInviteHintState extends State<RoomInviteHint> {
  RoomInviteSession _fallback = RoomInviteSession();
  RoomInviteSession get _session => widget.session ?? _fallback;
  bool get _inviteShown => _session.shown;
  set _inviteShown(bool value) => _session.shown = value;
  bool? get _eligibleOnEntry => _session.eligibleOnEntry;
  set _eligibleOnEntry(bool? value) => _session.eligibleOnEntry = value;
  String get roomId => widget.roomId;

  @override
  void didUpdateWidget(covariant RoomInviteHint oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomId != roomId) {
      _fallback = RoomInviteSession();
    }
  }

  void _offerInvite(RoomState roomState, String? code, String? userId) {
    if (_inviteShown ||
        roomState.status != RoomStatus.ready ||
        userId == null) {
      return;
    }
    final self = roomState.members
        .where((member) => member.userId == userId)
        .firstOrNull;
    if (self == null) return;
    // Decide from the first loaded membership snapshot, independently of when
    // the room code arrives. Later departures are not a new room entry.
    _eligibleOnEntry ??= roomState.members.length == 1 && self.isHost;
    if (!_eligibleOnEntry!) return;
    if (roomState.members.length != 1) {
      _eligibleOnEntry = false;
      return;
    }
    if (code == null ||
        code.isEmpty ||
        roomState.status != RoomStatus.ready ||
        roomState.members.length != 1 ||
        roomState.members.first.userId != userId ||
        !roomState.members.first.isHost) {
      return;
    }
    _inviteShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      final current = widget.roomState;
      if (current.status != RoomStatus.ready || current.members.length != 1) {
        return;
      }
      final copy = await AppDialog.confirm(
        context,
        title: 'Music is better together',
        message:
            'You are the first one here. Share your room code and invite friends to listen with you.',
        confirmLabel: 'Copy room code',
        cancelLabel: 'Later',
        icon: Icons.group_add_outlined,
        detail: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: SelectableText(
            code,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
            ),
          ),
        ),
      );
      if (!copy || !mounted) return;
      try {
        await Clipboard.setData(ClipboardData(text: code));
        if (mounted) {
          AppNotice.show(context, 'Room code copied', kind: NoticeKind.success);
        }
      } catch (_) {
        if (mounted) {
          AppNotice.show(
            context,
            'Could not copy the room code.',
            kind: NoticeKind.error,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _offerInvite(widget.roomState, widget.roomCode, widget.currentUserId);
    return widget.child;
  }
}
