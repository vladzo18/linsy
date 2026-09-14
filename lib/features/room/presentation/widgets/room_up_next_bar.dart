import 'dart:async';
import 'package:flutter/material.dart';
import 'room_player_overlay_phase.dart';

/// Room metadata below the embed, never an overlay on YouTube content.
class RoomUpNextBar extends StatefulWidget {
  const RoomUpNextBar({
    super.key,
    required this.phase,
    required this.nextTitle,
    required this.seconds,
    required this.scheduledStartAt,
    required this.now,
  });
  final PlayerOverlayPhase phase;
  final String? nextTitle;
  final int seconds;
  final DateTime? scheduledStartAt;
  final DateTime Function() now;
  @override
  State<RoomUpNextBar> createState() => _RoomUpNextBarState();
}

class _RoomUpNextBarState extends State<RoomUpNextBar> {
  late final Timer _timer = Timer.periodic(const Duration(milliseconds: 200), (
    _,
  ) {
    if (mounted && widget.scheduledStartAt != null) setState(() {});
  });
  @override
  void initState() {
    super.initState();
    _timer;
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preparing =
        widget.phase == PlayerOverlayPhase.preparingNext ||
        widget.phase == PlayerOverlayPhase.preparingRepeat;
    if (preparing &&
        widget.scheduledStartAt != null &&
        !widget.now().isBefore(widget.scheduledStartAt!)) {
      return const SizedBox.shrink();
    }
    final seconds = preparing && widget.scheduledStartAt != null
        ? (widget.scheduledStartAt!.difference(widget.now()).inMilliseconds /
                  1000)
              .ceil()
              .clamp(0, 999)
        : widget.seconds;
    final countdown = widget.phase != PlayerOverlayPhase.none;
    return SizedBox(
      height: 40,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Text(
              preparing
                  ? (widget.phase == PlayerOverlayPhase.preparingRepeat
                        ? 'REPLAYING'
                        : 'STARTING')
                  : 'UP NEXT',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.nextTitle ?? 'End of queue',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (countdown) ...[const SizedBox(width: 8), Text('${seconds}s')],
          ],
        ),
      ),
    );
  }
}
