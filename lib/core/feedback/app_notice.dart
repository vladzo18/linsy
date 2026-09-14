import 'dart:async';
import 'feedback_region.dart';
import '../media/player_visibility.dart';
import 'package:flutter/material.dart';

enum NoticeKind { success, error, info }

/// Transient, non-blocking feedback. One notice per root overlay, newest wins.
abstract final class AppNotice {
  static final _entries = Expando<OverlayEntry>();

  static void show(
    BuildContext context,
    String message, {
    NoticeKind kind = NoticeKind.info,
    Duration duration = const Duration(seconds: 4),
  }) {
    final region = FeedbackRegion.overlayOf(context);
    final overlay = region ?? Overlay.of(context, rootOverlay: true);
    final previous = _entries[overlay];
    previous?.remove();
    previous?.dispose();
    late OverlayEntry entry;
    void remove() {
      if (_entries[overlay] != entry) return;
      _entries[overlay] = null;
      entry.remove();
      entry.dispose();
    }

    entry = OverlayEntry(
      builder: (_) => _Notice(
        message: message,
        kind: kind,
        duration: duration,
        onDismiss: remove,
        blocksPlayer: region == null,
      ),
    );
    _entries[overlay] = entry;
    overlay.insert(entry);
  }
}

class _Notice extends StatefulWidget {
  const _Notice({
    required this.message,
    required this.kind,
    required this.duration,
    required this.onDismiss,
    required this.blocksPlayer,
  });
  final String message;
  final NoticeKind kind;
  final Duration duration;
  final VoidCallback onDismiss;
  final bool blocksPlayer;
  @override
  State<_Notice> createState() => _NoticeState();
}

class _NoticeState extends State<_Notice> with SingleTickerProviderStateMixin {
  VoidCallback? _releasePlayer;
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    reverseDuration: const Duration(milliseconds: 220),
  );
  Timer? _timer;
  bool _closing = false;
  @override
  void initState() {
    super.initState();
    // An opaque notice may cross the video area on small windows.
    // Remove the embed from painting and suspend local playback while it exists.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.blocksPlayer) {
        _releasePlayer = playerVisibility.block();
      }
    });
    _animation.forward();
    _timer = Timer(widget.duration, _close);
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    // Tickers may be suspended while another route/window is active. A notice
    // must still expire and release its playback blocker in that case.
    _animation.reverse();
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (mounted) widget.onDismiss();
  }

  @override
  void dispose() {
    _releasePlayer?.call();
    _timer?.cancel();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (widget.kind) {
      NoticeKind.success => (
        const Color(0xff137747),
        Icons.check_circle_outline_rounded,
      ),
      NoticeKind.error => (
        const Color(0xffb32636),
        Icons.error_outline_rounded,
      ),
      NoticeKind.info => (const Color(0xff4055ad), Icons.info_outline_rounded),
    };
    final motion = _animation.drive(CurveTween(curve: Curves.easeOutCubic));
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Positioned(
      top: widget.blocksPlayer ? 12 : 4,
      left: widget.blocksPlayer ? 12 : 8,
      right: widget.blocksPlayer ? 12 : 8,
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: FadeTransition(
              opacity: motion,
              child: SlideTransition(
                position: Tween(
                  begin: reduced ? Offset.zero : const Offset(0, -0.75),
                  end: Offset.zero,
                ).animate(motion),
                child: ScaleTransition(
                  alignment: Alignment.topCenter,
                  scale: reduced
                      ? const AlwaysStoppedAnimation(1.0)
                      : _animation
                            .drive(CurveTween(curve: Curves.easeOutBack))
                            .drive(Tween<double>(begin: 0.90, end: 1.0)),
                  child: Semantics(
                    liveRegion: true,
                    container: true,
                    child: Material(
                      color: color,
                      elevation: 8,
                      shadowColor: color.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(18),
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          12,
                          widget.blocksPlayer ? 8 : 0,
                          4,
                          widget.blocksPlayer ? 8 : 0,
                        ),
                        child: Row(
                          children: [
                            Icon(icon, color: Colors.white),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.message,
                                maxLines: widget.blocksPlayer ? null : 2,
                                overflow: widget.blocksPlayer
                                    ? null
                                    : TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Dismiss',
                              onPressed: _close,
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
