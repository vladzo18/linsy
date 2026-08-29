import 'package:flutter/material.dart';

class PlaybackTimeline extends StatefulWidget {
  const PlaybackTimeline({
    super.key,
    required this.positionMs,
    required this.durationMs,
    required this.canControlPlayback,
    required this.onSeek,
    required this.onRequestSeek,
    this.compact = false,
  });

  final int positionMs;
  final int durationMs;

  final bool canControlPlayback;

  final bool compact;

  /// Host / Moderator.
  final Future<void> Function(int positionMs) onSeek;

  /// Member.
  final Future<void> Function(int positionMs) onRequestSeek;

  @override
  State<PlaybackTimeline> createState() => _PlaybackTimelineState();
}

class _PlaybackTimelineState extends State<PlaybackTimeline> {
  double? _hoverX;

  bool _busy = false;

  // ============================================================
  // POSITION
  // ============================================================

  int _positionFromX(double x, double width) {
    if (width <= 0 || widget.durationMs <= 0) {
      return 0;
    }

    final normalized = (x / width).clamp(0.0, 1.0);

    return (widget.durationMs * normalized).round();
  }

  // ============================================================
  // CLICK / TAP
  // ============================================================

  Future<void> _handleSeek(BuildContext context, double x, double width) async {
    if (_busy || widget.durationMs <= 0) {
      return;
    }

    final targetPosition = _positionFromX(x, width);

    if (widget.canControlPlayback) {
      await _runBusy(() => widget.onSeek(targetPosition));

      return;
    }

    final confirmed = await _showSeekRequestDialog(context, targetPosition);

    if (confirmed != true || !mounted) {
      return;
    }

    await _runBusy(() => widget.onRequestSeek(targetPosition));
  }

  // ============================================================
  // BUSY
  // ============================================================

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      await action();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  // ============================================================
  // MEMBER DIALOG
  // ============================================================

  Future<bool?> _showSeekRequestDialog(
    BuildContext context,
    int targetPositionMs,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Request seek'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Send a request to change '
                'the playback position?',
              ),
              const SizedBox(height: 16),
              _TimeRow(
                label: 'Current position',
                value: _formatDuration(widget.positionMs),
              ),
              const SizedBox(height: 8),
              _TimeRow(
                label: 'Requested position',
                value: _formatDuration(targetPositionMs),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Send request'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final duration = widget.durationMs;

    final position = widget.positionMs.clamp(0, duration > 0 ? duration : 0);

    final progress = duration <= 0 ? 0.0 : position / duration;

    final interactionHeight = widget.compact ? 32.0 : 44.0;

    final trackHeight = widget.compact ? 5.0 : 6.0;

    final thumbSize = widget.compact ? 12.0 : 14.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

            final hoverX = _hoverX?.clamp(0.0, width);

            final hoverPosition = hoverX == null
                ? null
                : _positionFromX(hoverX, width);

            return MouseRegion(
              cursor: _busy
                  ? SystemMouseCursors.basic
                  : SystemMouseCursors.click,
              onHover: (event) {
                setState(() {
                  _hoverX = event.localPosition.dx;
                });
              },
              onExit: (_) {
                setState(() {
                  _hoverX = null;
                });
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: _busy
                    ? null
                    : (details) {
                        _handleSeek(context, details.localPosition.dx, width);
                      },
                child: SizedBox(
                  height: interactionHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.centerLeft,
                    children: [
                      // =========================================
                      // TRACK
                      // =========================================
                      Positioned(
                        left: 0,
                        right: 0,
                        top: (interactionHeight - trackHeight) / 2,
                        height: trackHeight,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),

                      // =========================================
                      // PROGRESS
                      // =========================================
                      Positioned(
                        left: 0,
                        top: (interactionHeight - trackHeight) / 2,
                        width: width * progress,
                        height: trackHeight,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),

                      // =========================================
                      // CURRENT THUMB
                      // =========================================
                      Positioned(
                        left: (width * progress - thumbSize / 2).clamp(
                          0.0,
                          width - thumbSize,
                        ),
                        top: (interactionHeight - thumbSize) / 2,
                        child: Container(
                          width: thumbSize,
                          height: thumbSize,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                blurRadius: widget.compact ? 3 : 4,
                                color: Colors.black.withValues(alpha: 0.25),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // =========================================
                      // HOVER POSITION
                      // =========================================
                      if (hoverX != null && hoverPosition != null)
                        Positioned(
                          left: (hoverX - 24).clamp(0.0, width - 48),
                          top: widget.compact ? -10 : -4,
                          child: IgnorePointer(
                            child: Container(
                              width: 48,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.inverseSurface,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                _formatDuration(hoverPosition),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onInverseSurface,
                                ),
                              ),
                            ),
                          ),
                        ),

                      // =========================================
                      // BUSY
                      // =========================================
                      if (_busy)
                        const Positioned(
                          right: 0,
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),

        // ======================================================
        // TIMES
        // ======================================================
        Row(
          children: [
            Text(
              _formatDuration(position),
              style: (widget.compact
                  ? Theme.of(context).textTheme.labelSmall
                  : Theme.of(context).textTheme.bodySmall),
            ),

            const Spacer(),

            Text(
              _formatDuration(duration),
              style: (widget.compact
                  ? Theme.of(context).textTheme.labelSmall
                  : Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================
// TIME ROW
// ============================================================

class _TimeRow extends StatelessWidget {
  const _TimeRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 16),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ============================================================
// FORMAT
// ============================================================

String _formatDuration(int milliseconds) {
  final safeMilliseconds = milliseconds < 0 ? 0 : milliseconds;

  final totalSeconds = safeMilliseconds ~/ 1000;

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
