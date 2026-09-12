import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/models/playback_state.dart';
import '../../domain/models/room_queue_item.dart';
import 'room_player_overlay_phase.dart';
import 'room_player_transition_visuals.dart';

class PlayerTransitionOverlay extends StatefulWidget {
  const PlayerTransitionOverlay({
    super.key,
    required this.phase,
    required this.playback,
    required this.nextTrack,
    required this.remainingSeconds,
    required this.scheduledStartAt,
    required this.now,
    required this.compact,
    required this.canControlPlayback,
    required this.onRestart,
    required this.onNext,
  });

  final PlayerOverlayPhase phase;

  final PlaybackState playback;
  final RoomQueueItem? nextTrack;

  final int remainingSeconds;

  final DateTime? scheduledStartAt;
  final DateTime Function() now;

  final bool compact;
  final bool canControlPlayback;

  final Future<void> Function() onRestart;
  final Future<void> Function() onNext;

  @override
  State<PlayerTransitionOverlay> createState() =>
      _PlayerTransitionOverlayState();
}

class _PlayerTransitionOverlayState extends State<PlayerTransitionOverlay>
    with TickerProviderStateMixin {
  Timer? _timer;

  Duration _scheduledRemaining = Duration.zero;

  late final AnimationController _ambientController;

  late final AnimationController _entryController;

  int _countdownStartSeconds = 1;

  bool get _isPreparing =>
      widget.phase == PlayerOverlayPhase.preparingNext ||
      widget.phase == PlayerOverlayPhase.preparingRepeat;

  @override
  void initState() {
    super.initState();

    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();

    _updateTimer();
    if (_isPreparing) {
      _countdownStartSeconds = math.max(1, _scheduledSeconds);
    } else {
      _countdownStartSeconds = math.max(1, widget.remainingSeconds);
    }
  }

  @override
  void didUpdateWidget(covariant PlayerTransitionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Новый ending-overlay.
    if (widget.phase == PlayerOverlayPhase.ending &&
        oldWidget.phase != PlayerOverlayPhase.ending) {
      _countdownStartSeconds = math.max(1, widget.remainingSeconds);
    }

    // Новый трек, но overlay уже существовал.
    if (oldWidget.playback.trackId != widget.playback.trackId &&
        widget.phase == PlayerOverlayPhase.ending) {
      _countdownStartSeconds = math.max(1, widget.remainingSeconds);
    }

    if (oldWidget.phase != widget.phase ||
        oldWidget.scheduledStartAt != widget.scheduledStartAt ||
        oldWidget.playback.trackId != widget.playback.trackId) {
      _updateTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();

    _ambientController.dispose();
    _entryController.dispose();

    super.dispose();
  }

  int get _scheduledSeconds {
    if (_scheduledRemaining.inMilliseconds <= 0) {
      return 0;
    }

    return (_scheduledRemaining.inMilliseconds / 1000).ceil();
  }

  int get _visibleSeconds {
    if (_isPreparing) {
      return _scheduledSeconds;
    }

    return widget.remainingSeconds;
  }

  Duration _calculateScheduledRemaining() {
    final scheduled = widget.scheduledStartAt;

    if (!_isPreparing || scheduled == null) {
      return Duration.zero;
    }

    final remaining = scheduled.toUtc().difference(widget.now().toUtc());

    if (remaining.isNegative) {
      return Duration.zero;
    }

    return remaining;
  }

  void _updateTimer() {
    _timer?.cancel();

    _timer = null;

    _scheduledRemaining = _calculateScheduledRemaining();

    if (!_isPreparing || _scheduledRemaining.inMilliseconds <= 0) {
      return;
    }

    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final remaining = _calculateScheduledRemaining();

      if (!mounted) {
        return;
      }

      setState(() {
        _scheduledRemaining = remaining;
      });

      if (remaining.inMilliseconds <= 0) {
        _timer?.cancel();
        _timer = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.phase == PlayerOverlayPhase.none) {
      return const SizedBox.shrink();
    }

    if (_isPreparing && _scheduledRemaining.inMilliseconds <= 0) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    final accent = theme.colorScheme.primary;

    final content = _resolveContent();

    final seconds = math.max(0, _visibleSeconds);

    final paused =
        widget.phase == PlayerOverlayPhase.ending && !widget.playback.isPlaying;

    final progress = _calculateProgress(seconds);

    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _entryController,
        curve: Curves.easeOutCubic,
      ),
      child: Material(
        color: Colors.transparent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // BACKGROUND
            ColoredBox(
              color: Color.alphaBlend(
                theme.colorScheme.primary.withValues(alpha: 0.06),
                const Color(0xFF090A0E),
              ),
            ),

            // MOVING GLOW + PARTICLES
            CustomPaint(
              painter: TransitionAtmospherePainter(
                animation: _ambientController,
                accent: accent,
              ),
            ),

            // DARKEN EDGES
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 1.1,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.52),
                    ],
                    stops: const [0.35, 1],
                  ),
                ),
              ),
            ),

            // CONTENT
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? 18 : 34,
                vertical: widget.compact ? 14 : 24,
              ),
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) => FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: math.min(720.0, constraints.maxWidth),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        transitionBuilder: (child, animation) {
                          final slide =
                              Tween<Offset>(
                                begin: const Offset(0, 0.035),
                                end: Offset.zero,
                              ).animate(
                                CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutCubic,
                                ),
                              );

                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: slide,
                              child: child,
                            ),
                          );
                        },
                        child: Column(
                          key: ValueKey(widget.phase),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // PHASE BADGE
                            TransitionBadge(
                              phase: widget.phase,
                              paused: paused,
                              accent: accent,
                              compact: widget.compact,
                            ),

                            SizedBox(height: widget.compact ? 12 : 18),

                            // MAIN CARD
                            Container(
                              padding: EdgeInsets.all(widget.compact ? 12 : 16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.055),
                                borderRadius: BorderRadius.circular(
                                  widget.compact ? 18 : 24,
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withValues(alpha: 0.10),
                                    blurRadius: 34,
                                    spreadRadius: -12,
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  // ARTWORK
                                  AnimatedArtwork(
                                    thumbnailUrl: content.thumbnailUrl,
                                    compact: widget.compact,
                                    accent: accent,
                                    animation: _ambientController,
                                  ),

                                  SizedBox(width: widget.compact ? 12 : 18),

                                  // TRACK
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          content.label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.48,
                                            ),
                                            fontSize: widget.compact ? 10 : 12,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.3,
                                          ),
                                        ),

                                        const SizedBox(height: 4),

                                        Text(
                                          content.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: widget.compact ? 15 : 20,
                                            height: 1.15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),

                                        SizedBox(
                                          height: widget.compact ? 6 : 8,
                                        ),

                                        TransitionStatus(
                                          phase: widget.phase,
                                          paused: paused,
                                          hasNext: widget.nextTrack != null,
                                          accent: accent,
                                          compact: widget.compact,
                                        ),
                                      ],
                                    ),
                                  ),

                                  SizedBox(width: widget.compact ? 10 : 18),

                                  // COUNTDOWN
                                  CountdownOrb(
                                    seconds: seconds,
                                    progress: progress,
                                    accent: accent,
                                    compact: widget.compact,
                                    paused: paused,
                                  ),
                                ],
                              ),
                            ),

                            // ACTIONS
                            SizedBox(height: widget.compact ? 12 : 16),

                            SizedBox(
                              height: widget.compact ? 42 : 46,
                              child: IgnorePointer(
                                ignoring:
                                    widget.phase != PlayerOverlayPhase.ending,
                                child: AnimatedOpacity(
                                  opacity:
                                      widget.phase == PlayerOverlayPhase.ending
                                      ? 1
                                      : 0,
                                  duration: const Duration(milliseconds: 260),
                                  curve: Curves.easeOutCubic,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        child: FilledButton.tonalIcon(
                                          onPressed: () async {
                                            await widget.onRestart();
                                          },
                                          icon: const Icon(
                                            Icons.replay_rounded,
                                          ),
                                          label: Text(
                                            widget.canControlPlayback
                                                ? 'Restart current'
                                                : 'Request restart',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),

                                      if (widget.nextTrack != null) ...[
                                        SizedBox(
                                          width: widget.compact ? 8 : 10,
                                        ),

                                        Flexible(
                                          child: FilledButton.icon(
                                            onPressed: () async {
                                              await widget.onNext();
                                            },
                                            icon: const Icon(
                                              Icons.skip_next_rounded,
                                            ),
                                            label: Text(
                                              widget.canControlPlayback
                                                  ? 'Play next now'
                                                  : 'Request next',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
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
          ],
        ),
      ),
    );
  }

  double _calculateProgress(int seconds) {
    final total = math.max(1, _countdownStartSeconds);

    final remaining = seconds.clamp(0, total);

    return 1 - (remaining / total);
  }

  _TransitionContent _resolveContent() {
    // ENDING

    if (widget.phase == PlayerOverlayPhase.ending) {
      final next = widget.nextTrack;

      if (next != null) {
        return _TransitionContent(
          label: 'NEXT TRACK',
          title: _cleanTitle(next.title, next.trackId),
          thumbnailUrl: _cleanThumbnail(next.thumbnailUrl),
        );
      }

      return _TransitionContent(
        label: 'CURRENT TRACK',
        title: _cleanTitle(
          widget.playback.title,
          widget.playback.trackId ?? '',
        ),
        thumbnailUrl: _cleanThumbnail(widget.playback.thumbnailUrl),
      );
    }

    // PREPARING

    return _TransitionContent(
      label: widget.phase == PlayerOverlayPhase.preparingRepeat
          ? 'RESTARTING'
          : 'NEXT TRACK',
      title: _cleanTitle(widget.playback.title, widget.playback.trackId ?? ''),
      thumbnailUrl: _cleanThumbnail(widget.playback.thumbnailUrl),
    );
  }

  String _cleanTitle(String? value, String fallback) {
    final title = value?.trim();

    if (title == null || title.isEmpty) {
      return fallback;
    }

    return title;
  }

  String? _cleanThumbnail(String? value) {
    final thumbnail = value?.trim();

    if (thumbnail == null || thumbnail.isEmpty) {
      return null;
    }

    return thumbnail;
  }
}

// TRANSITION CONTENT

class _TransitionContent {
  const _TransitionContent({
    required this.label,
    required this.title,
    required this.thumbnailUrl,
  });

  final String label;
  final String title;
  final String? thumbnailUrl;
}
