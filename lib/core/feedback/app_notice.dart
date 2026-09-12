import 'dart:async';
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
    final overlay = Overlay.of(context, rootOverlay: true);
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
  });
  final String message;
  final NoticeKind kind;
  final Duration duration;
  final VoidCallback onDismiss;
  @override
  State<_Notice> createState() => _NoticeState();
}

class _NoticeState extends State<_Notice> with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Timer? _timer;
  bool _closing = false;
  @override
  void initState() {
    super.initState();
    _animation.forward();
    _timer = Timer(widget.duration, _close);
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    await _animation.reverse();
    if (mounted) widget.onDismiss();
  }

  @override
  void dispose() {
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
    final motion = CurvedAnimation(
      parent: _animation,
      curve: Curves.easeOutCubic,
    );
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Positioned(
      top: 12,
      left: 12,
      right: 12,
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
                  begin: reduced ? Offset.zero : const Offset(0, -0.3),
                  end: Offset.zero,
                ).animate(motion),
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
                      padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                      child: Row(
                        children: [
                          Icon(icon, color: Colors.white),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.message,
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
    );
  }
}
