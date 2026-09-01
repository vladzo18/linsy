import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:linsy/core/time/server_clock.dart';
import 'package:linsy/features/room/player/player_surface.dart';

import '../../../library/application/saved_tracks_controller.dart';
import '../../domain/models/playback_state.dart';
import '../../domain/models/room_queue_item.dart';
import 'playback_timeline.dart';
import 'player_volume_control.dart';

class RoomPlayerCard extends ConsumerWidget {
  const RoomPlayerCard({
    super.key,
    required this.playback,
    required this.nextTrack,
    required this.livePositionMs,
    required this.canControlPlayback,
    required this.onPlayPause,
    required this.onNext,
    required this.onSeek,
    required this.onRequestPlayPause,
    required this.onRequestNext,
    required this.onRequestSeek,
  });

  final PlaybackState playback;

  final RoomQueueItem? nextTrack;

  final int livePositionMs;

  final bool canControlPlayback;

  final Future<void> Function() onPlayPause;

  final Future<void> Function() onNext;

  final Future<void> Function(int positionMs) onSeek;

  final Future<void> Function() onRequestPlayPause;

  final Future<void> Function() onRequestNext;

  final Future<void> Function(int positionMs) onRequestSeek;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverClock = ref.watch(serverClockProvider).value;

    return LayoutBuilder(
      builder: (context, constraints) {
        final trackId = playback.trackId;

        final hasTrack = trackId != null;

        final compact = constraints.maxWidth < 600;

        final durationMs = playback.durationMs ?? 0;

        final serverNow = serverClock?.now() ?? DateTime.now().toUtc();

        final authoritativePositionMs = playback.positionAt(serverNow);

        final authoritativeRemainingMs = durationMs > 0
            ? (durationMs - authoritativePositionMs).clamp(0, durationMs)
            : 0;

        final preparationDurationMs = nextTrack != null ? 3000 : 2000;

        final endingCountdownSeconds =
            ((authoritativeRemainingMs + preparationDurationMs) / 1000).ceil();

        final scheduledStartAt = playback.scheduledStartAt?.toUtc();

        final waitingForScheduledStart =
            playback.isPlaying &&
            scheduledStartAt != null &&
            serverNow.isBefore(scheduledStartAt);

        final transitionKind = playback.transitionKind;

        final _PlayerOverlayPhase overlayPhase;

        if (waitingForScheduledStart && transitionKind == 'next') {
          overlayPhase = _PlayerOverlayPhase.preparingNext;
        } else if (waitingForScheduledStart && transitionKind == 'repeat') {
          overlayPhase = _PlayerOverlayPhase.preparingRepeat;
        } else if (hasTrack &&
            durationMs > 0 &&
            authoritativeRemainingMs <= 10000) {
          overlayPhase = _PlayerOverlayPhase.ending;
        } else {
          overlayPhase = _PlayerOverlayPhase.none;
        }

        final effectiveNext = canControlPlayback ? onNext : onRequestNext;

        final Future<void> Function() restartCurrent = canControlPlayback
            ? () => onSeek(0)
            : () => onRequestSeek(0);

        return Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ===================================================
              // VIDEO
              // ===================================================
              Expanded(
                child: ColoredBox(
                  color: Colors.black,
                  child: Center(
                    child: hasTrack
                        ? AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                PlayerSurface(trackId: trackId),

                                if (overlayPhase != _PlayerOverlayPhase.none)
                                  _PlayerTransitionOverlay(
                                    phase: overlayPhase,
                                    playback: playback,
                                    nextTrack: nextTrack,
                                    remainingSeconds: endingCountdownSeconds,
                                    scheduledStartAt: scheduledStartAt,
                                    now: () =>
                                        serverClock?.now() ??
                                        DateTime.now().toUtc(),
                                    compact: compact,
                                    canControlPlayback: canControlPlayback,
                                    onRestart: restartCurrent,
                                    onNext: effectiveNext,
                                  ),
                              ],
                            ),
                          )
                        : const _EmptyPlayer(),
                  ),
                ),
              ),

              // ===================================================
              // CURRENT TRACK CONTROLS
              // ===================================================
              if (hasTrack)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 12 : 18,
                    compact ? 6 : 8,
                    compact ? 12 : 18,
                    compact ? 7 : 10,
                  ),
                  child: Column(
                    children: [
                      PlaybackTimeline(
                        positionMs: livePositionMs,
                        durationMs: playback.durationMs ?? 0,
                        canControlPlayback: canControlPlayback,
                        onSeek: onSeek,
                        onRequestSeek: onRequestSeek,
                        compact: compact,
                      ),

                      SizedBox(height: compact ? 4 : 6),

                      _PlayerControlsRow(
                        playback: playback,
                        isPlaying: playback.isPlaying,
                        canControlPlayback: canControlPlayback,
                        compact: compact,
                        onPlayPause: canControlPlayback
                            ? onPlayPause
                            : onRequestPlayPause,
                        onNext: canControlPlayback ? onNext : onRequestNext,
                      ),
                    ],
                  ),
                ),

              // ===================================================
              // NO CURRENT TRACK
              // ===================================================
              if (!hasTrack && canControlPlayback)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 12 : 18,
                    compact ? 8 : 10,
                    compact ? 12 : 18,
                    compact ? 8 : 10,
                  ),
                  child: _StartQueueControls(compact: compact, onStart: onNext),
                ),
            ],
          ),
        );
      },
    );
  }
}

// =====================================================================
// PLAYER TRANSITION OVERLAY
// =====================================================================

enum _PlayerOverlayPhase { none, ending, preparingNext, preparingRepeat }

class _PlayerTransitionOverlay extends StatefulWidget {
  const _PlayerTransitionOverlay({
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

  final _PlayerOverlayPhase phase;

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
  State<_PlayerTransitionOverlay> createState() =>
      _PlayerTransitionOverlayState();
}

class _PlayerTransitionOverlayState extends State<_PlayerTransitionOverlay>
    with TickerProviderStateMixin {
  Timer? _timer;

  Duration _scheduledRemaining = Duration.zero;

  late final AnimationController _ambientController;

  late final AnimationController _entryController;

  int _countdownStartSeconds = 1;

  bool get _isPreparing =>
      widget.phase == _PlayerOverlayPhase.preparingNext ||
      widget.phase == _PlayerOverlayPhase.preparingRepeat;

  bool get _isRepeat =>
      widget.phase == _PlayerOverlayPhase.preparingRepeat ||
      (widget.phase == _PlayerOverlayPhase.ending && widget.nextTrack == null);

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
  void didUpdateWidget(covariant _PlayerTransitionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Новый ending-overlay.
    if (widget.phase == _PlayerOverlayPhase.ending &&
        oldWidget.phase != _PlayerOverlayPhase.ending) {
      _countdownStartSeconds = math.max(1, widget.remainingSeconds);
    }

    // Новый трек, но overlay уже существовал.
    if (oldWidget.playback.trackId != widget.playback.trackId &&
        widget.phase == _PlayerOverlayPhase.ending) {
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
    if (widget.phase == _PlayerOverlayPhase.none) {
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
        widget.phase == _PlayerOverlayPhase.ending &&
        !widget.playback.isPlaying;

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
            // ===========================================================
            // BACKGROUND
            // ===========================================================
            ColoredBox(
              color: Color.alphaBlend(
                theme.colorScheme.primary.withValues(alpha: 0.06),
                const Color(0xFF090A0E),
              ),
            ),

            // ===========================================================
            // MOVING GLOW + PARTICLES
            // ===========================================================
            CustomPaint(
              painter: _TransitionAtmospherePainter(
                animation: _ambientController,
                accent: accent,
              ),
            ),

            // ===========================================================
            // DARKEN EDGES
            // ===========================================================
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

            // ===========================================================
            // CONTENT
            // ===========================================================
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? 18 : 34,
                vertical: widget.compact ? 14 : 24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
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
                        child: SlideTransition(position: slide, child: child),
                      );
                    },
                    child: Column(
                      key: ValueKey(widget.phase),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ===============================================
                        // PHASE BADGE
                        // ===============================================
                        _TransitionBadge(
                          phase: widget.phase,
                          paused: paused,
                          accent: accent,
                          compact: widget.compact,
                        ),

                        SizedBox(height: widget.compact ? 12 : 18),

                        // ===============================================
                        // MAIN CARD
                        // ===============================================
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
                              // =========================================
                              // ARTWORK
                              // =========================================
                              _AnimatedArtwork(
                                thumbnailUrl: content.thumbnailUrl,
                                compact: widget.compact,
                                accent: accent,
                                animation: _ambientController,
                              ),

                              SizedBox(width: widget.compact ? 12 : 18),

                              // =========================================
                              // TRACK
                              // =========================================
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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

                                    SizedBox(height: widget.compact ? 6 : 8),

                                    _TransitionStatus(
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

                              // =========================================
                              // COUNTDOWN
                              // =========================================
                              _CountdownOrb(
                                seconds: seconds,
                                progress: progress,
                                accent: accent,
                                compact: widget.compact,
                                paused: paused,
                              ),
                            ],
                          ),
                        ),

                        // ===============================================
                        // ACTIONS
                        // ===============================================
                        SizedBox(height: widget.compact ? 12 : 16),

                        SizedBox(
                          height: widget.compact ? 42 : 46,
                          child: IgnorePointer(
                            ignoring:
                                widget.phase != _PlayerOverlayPhase.ending,
                            child: AnimatedOpacity(
                              opacity:
                                  widget.phase == _PlayerOverlayPhase.ending
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
                                      icon: const Icon(Icons.replay_rounded),
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
                                    SizedBox(width: widget.compact ? 8 : 10),

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
    // ===========================================================
    // ENDING
    // ===========================================================

    if (widget.phase == _PlayerOverlayPhase.ending) {
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

    // ===========================================================
    // PREPARING
    // ===========================================================

    return _TransitionContent(
      label: widget.phase == _PlayerOverlayPhase.preparingRepeat
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

// =====================================================================
// TRANSITION CONTENT
// =====================================================================

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

// =====================================================================
// PHASE BADGE
// =====================================================================

class _TransitionBadge extends StatelessWidget {
  const _TransitionBadge({
    required this.phase,
    required this.paused,
    required this.accent,
    required this.compact,
  });

  final _PlayerOverlayPhase phase;

  final bool paused;

  final Color accent;

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final String text;

    if (paused) {
      icon = Icons.pause_rounded;
      text = 'PAUSED';
    } else {
      switch (phase) {
        case _PlayerOverlayPhase.ending:
          icon = Icons.skip_next_rounded;
          text = 'UP NEXT';

        case _PlayerOverlayPhase.preparingNext:
          icon = Icons.sync_rounded;
          text = 'PREPARING NEXT';

        case _PlayerOverlayPhase.preparingRepeat:
          icon = Icons.replay_rounded;
          text = 'PLAYING AGAIN';

        case _PlayerOverlayPhase.none:
          icon = Icons.music_note_rounded;
          text = '';
      }
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 14 : 16, color: accent),

          const SizedBox(width: 6),

          Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// STATUS
// =====================================================================

class _TransitionStatus extends StatelessWidget {
  const _TransitionStatus({
    required this.phase,
    required this.paused,
    required this.hasNext,
    required this.accent,
    required this.compact,
  });

  final _PlayerOverlayPhase phase;

  final bool paused;
  final bool hasNext;

  final Color accent;

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final String text;

    if (paused) {
      text = 'Countdown paused';
    } else {
      switch (phase) {
        case _PlayerOverlayPhase.ending:
          text = hasNext ? 'Starts automatically' : 'Will replay automatically';

        case _PlayerOverlayPhase.preparingNext:
          text = 'Synchronizing all devices';

        case _PlayerOverlayPhase.preparingRepeat:
          text = 'Synchronizing restart';

        case _PlayerOverlayPhase.none:
          text = '';
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: paused ? Colors.white54 : accent,
            shape: BoxShape.circle,
            boxShadow: paused
                ? null
                : [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.55),
                      blurRadius: 7,
                    ),
                  ],
          ),
        ),

        const SizedBox(width: 6),

        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.52),
              fontSize: compact ? 9 : 11,
            ),
          ),
        ),
      ],
    );
  }
}

// =====================================================================
// ARTWORK
// =====================================================================

class _AnimatedArtwork extends StatelessWidget {
  const _AnimatedArtwork({
    required this.thumbnailUrl,
    required this.compact,
    required this.accent,
    required this.animation,
  });

  final String? thumbnailUrl;
  final bool compact;

  final Color accent;

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final wave = (math.sin(animation.value * math.pi * 2) + 1) / 2;

        final scale = 1 + (wave * 0.018);

        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(compact ? 11 : 15),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.85),
              Colors.white.withValues(alpha: 0.18),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.22),
              blurRadius: 24,
              spreadRadius: -7,
            ),
          ],
        ),
        child: _OverlayThumbnail(thumbnailUrl: thumbnailUrl, compact: compact),
      ),
    );
  }
}

// =====================================================================
// COUNTDOWN ORB
// =====================================================================

class _CountdownOrb extends StatelessWidget {
  const _CountdownOrb({
    required this.seconds,
    required this.progress,
    required this.accent,
    required this.compact,
    required this.paused,
  });

  final int seconds;
  final double progress;

  final Color accent;

  final bool compact;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 72.0 : 92.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: progress.clamp(0, 1)),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return SizedBox.expand(
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: compact ? 3 : 4,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  color: paused ? Colors.white38 : accent,
                  strokeCap: StrokeCap.round,
                ),
              );
            },
          ),

          Container(
            margin: EdgeInsets.all(compact ? 8 : 10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.055)),
            ),
          ),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, animation) {
              final scale = Tween<double>(begin: 0.72, end: 1).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
              );

              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: scale, child: child),
              );
            },
            child: Column(
              key: ValueKey(seconds),
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$seconds',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 25 : 34,
                    height: 0.95,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                SizedBox(height: compact ? 2 : 3),

                Text(
                  'SEC',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.38),
                    fontSize: compact ? 7 : 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// PARTICLES / AMBIENT BACKGROUND
// =====================================================================

class _TransitionAtmospherePainter extends CustomPainter {
  _TransitionAtmospherePainter({required this.animation, required this.accent})
    : super(repaint: animation);

  final Animation<double> animation;

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;

    _paintGlow(canvas, size, t);

    _paintParticles(canvas, size, t);
  }

  void _paintGlow(Canvas canvas, Size size, double t) {
    final waveX = math.sin(t * math.pi * 2);

    final waveY = math.cos(t * math.pi * 2);

    final firstCenter = Offset(
      size.width * (0.28 + waveX * 0.05),
      size.height * (0.42 + waveY * 0.05),
    );

    final secondCenter = Offset(
      size.width * (0.77 - waveX * 0.04),
      size.height * (0.62 - waveY * 0.04),
    );

    final firstPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              accent.withValues(alpha: 0.20),
              accent.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(center: firstCenter, radius: size.width * 0.48),
          );

    canvas.drawCircle(firstCenter, size.width * 0.48, firstPaint);

    final secondPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [Colors.white.withValues(alpha: 0.045), Colors.transparent],
          ).createShader(
            Rect.fromCircle(center: secondCenter, radius: size.width * 0.32),
          );

    canvas.drawCircle(secondCenter, size.width * 0.32, secondPaint);
  }

  void _paintParticles(Canvas canvas, Size size, double t) {
    final paint = Paint();

    const count = 22;

    for (var i = 0; i < count; i++) {
      final baseX = ((i * 71) % 100) / 100;

      final phase = ((i * 37) % 100) / 100;

      final speed = 0.18 + ((i % 5) * 0.035);

      final movement = (phase + t * speed) % 1;

      final y = size.height * (1.08 - movement * 1.18);

      final drift = math.sin((t * math.pi * 2) + i * 1.41) * size.width * 0.018;

      final x = size.width * baseX + drift;

      final radius = 0.8 + ((i % 4) * 0.55);

      final alpha = 0.055 + ((i % 5) * 0.018);

      paint.color = i % 3 == 0
          ? accent.withValues(alpha: alpha)
          : Colors.white.withValues(alpha: alpha * 0.82);

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TransitionAtmospherePainter oldDelegate) {
    return oldDelegate.accent != accent;
  }
}

class _ScheduledPlaybackOverlay extends StatefulWidget {
  const _ScheduledPlaybackOverlay({
    required this.playback,
    required this.scheduledStartAt,
    required this.now,
    required this.compact,
  });

  final PlaybackState playback;

  final DateTime scheduledStartAt;

  final DateTime Function() now;

  final bool compact;

  @override
  State<_ScheduledPlaybackOverlay> createState() =>
      _ScheduledPlaybackOverlayState();
}

class _ScheduledPlaybackOverlayState extends State<_ScheduledPlaybackOverlay> {
  Timer? _timer;

  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();

    _restartTimer();
  }

  @override
  void didUpdateWidget(covariant _ScheduledPlaybackOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.scheduledStartAt != widget.scheduledStartAt ||
        oldWidget.playback.trackId != widget.playback.trackId) {
      _restartTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();

    _timer = null;

    super.dispose();
  }

  Duration _calculateRemaining() {
    final remaining = widget.scheduledStartAt.toUtc().difference(
      widget.now().toUtc(),
    );

    if (remaining.isNegative) {
      return Duration.zero;
    }

    return remaining;
  }

  void _restartTimer() {
    _timer?.cancel();

    _timer = null;

    _remaining = _calculateRemaining();

    if (_remaining.inMilliseconds <= 0) {
      return;
    }

    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _tick();
    });
  }

  void _tick() {
    final next = _calculateRemaining();

    if (!mounted) {
      _remaining = next;

      return;
    }

    setState(() {
      _remaining = next;
    });

    if (next.inMilliseconds <= 0) {
      _timer?.cancel();

      _timer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining.inMilliseconds <= 0) {
      return const SizedBox.shrink();
    }

    final remainingSeconds = (_remaining.inMilliseconds / 1000).ceil();

    final titleValue = widget.playback.title?.trim();

    final title = titleValue == null || titleValue.isEmpty
        ? widget.playback.trackId ?? ''
        : titleValue;

    final thumbnailValue = widget.playback.thumbnailUrl?.trim();

    final thumbnailUrl = thumbnailValue == null || thumbnailValue.isEmpty
        ? null
        : thumbnailValue;

    return Material(
      color: const Color(0xFF0D0D0F),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: widget.compact ? 16 : 28,
          vertical: widget.compact ? 12 : 20,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'GETTING READY',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.58),
                fontSize: widget.compact ? 10 : 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.7,
              ),
            ),

            SizedBox(height: widget.compact ? 8 : 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _OverlayThumbnail(
                  thumbnailUrl: thumbnailUrl,
                  compact: widget.compact,
                ),

                SizedBox(width: widget.compact ? 12 : 18),

                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Starting',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: widget.compact ? 10 : 12,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: widget.compact ? 14 : 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: widget.compact ? 10 : 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: Text(
                    '$remainingSeconds',
                    key: ValueKey(remainingSeconds),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: widget.compact ? 36 : 50,
                      height: 1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                SizedBox(width: widget.compact ? 9 : 12),

                Text(
                  'starting in',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontSize: widget.compact ? 11 : 13,
                  ),
                ),
              ],
            ),

            SizedBox(height: widget.compact ? 7 : 10),

            Text(
              'Preparing player...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.42),
                fontSize: widget.compact ? 10 : 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// OVERLAY THUMBNAIL
// =====================================================================

class _OverlayThumbnail extends StatelessWidget {
  const _OverlayThumbnail({required this.thumbnailUrl, required this.compact});

  final String? thumbnailUrl;

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(compact ? 8 : 11),
      child: SizedBox(
        width: compact ? 112 : 150,
        height: compact ? 63 : 84,
        child: thumbnailUrl == null
            ? const ColoredBox(
                color: Colors.white10,
                child: Center(
                  child: Icon(
                    Icons.music_note_rounded,
                    color: Colors.white54,
                    size: 30,
                  ),
                ),
              )
            : Image.network(
                thumbnailUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const ColoredBox(
                    color: Colors.white10,
                    child: Center(
                      child: Icon(
                        Icons.music_note_rounded,
                        color: Colors.white54,
                        size: 30,
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

// =====================================================================
// START QUEUE
// =====================================================================

class _StartQueueControls extends StatelessWidget {
  const _StartQueueControls({required this.compact, required this.onStart});

  final bool compact;

  final Future<void> Function() onStart;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 44 : 50,
      child: Row(
        children: [
          SizedBox(
            width: compact ? 42 : 48,
            child: const Align(
              alignment: Alignment.centerLeft,
              child: PlayerVolumeControl(),
            ),
          ),

          Expanded(
            child: Center(
              child: FilledButton.tonalIcon(
                onPressed: () async {
                  await onStart();
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start queue'),
              ),
            ),
          ),

          SizedBox(width: compact ? 42 : 48),
        ],
      ),
    );
  }
}

// =====================================================================
// CONTROLS ROW
// =====================================================================

class _PlayerControlsRow extends StatelessWidget {
  const _PlayerControlsRow({
    required this.playback,
    required this.isPlaying,
    required this.canControlPlayback,
    required this.compact,
    required this.onPlayPause,
    required this.onNext,
  });

  final PlaybackState playback;

  final bool isPlaying;

  final bool canControlPlayback;

  final bool compact;

  final Future<void> Function() onPlayPause;

  final Future<void> Function() onNext;

  @override
  Widget build(BuildContext context) {
    final sideWidth = compact ? 42.0 : 48.0;

    return SizedBox(
      height: compact ? 44 : 50,
      child: Row(
        children: [
          SizedBox(
            width: sideWidth,
            child: const Align(
              alignment: Alignment.centerLeft,
              child: PlayerVolumeControl(),
            ),
          ),

          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Tooltip(
                  message: canControlPlayback
                      ? isPlaying
                            ? 'Pause'
                            : 'Play'
                      : isPlaying
                      ? 'Request pause'
                      : 'Request play',
                  child: IconButton.filledTonal(
                    onPressed: () async {
                      await onPlayPause();
                    },
                    icon: Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    iconSize: compact ? 24 : 26,
                    padding: EdgeInsets.all(compact ? 9 : 11),
                  ),
                ),

                SizedBox(width: compact ? 6 : 8),

                Tooltip(
                  message: canControlPlayback
                      ? 'Next track'
                      : 'Request next track',
                  child: IconButton(
                    onPressed: () async {
                      await onNext();
                    },
                    icon: const Icon(Icons.skip_next_rounded),
                    iconSize: compact ? 25 : 27,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(
            width: sideWidth,
            child: Align(
              alignment: Alignment.centerRight,
              child: _SaveTrackButton(playback: playback, compact: compact),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// SAVE TRACK
// =====================================================================

class _SaveTrackButton extends ConsumerStatefulWidget {
  const _SaveTrackButton({required this.playback, required this.compact});

  final PlaybackState playback;

  final bool compact;

  @override
  ConsumerState<_SaveTrackButton> createState() => _SaveTrackButtonState();
}

class _SaveTrackButtonState extends ConsumerState<_SaveTrackButton> {
  bool _changing = false;

  Future<void> _toggleSaved() async {
    if (_changing) {
      return;
    }

    final trackId = widget.playback.trackId?.trim();

    final source = widget.playback.source?.trim();

    if (trackId == null ||
        trackId.isEmpty ||
        source == null ||
        source.isEmpty) {
      return;
    }

    final controller = ref.read(savedTracksControllerProvider.notifier);

    final isSaved = controller.isSaved(source: source, trackId: trackId);

    setState(() {
      _changing = true;
    });

    try {
      if (isSaved) {
        await controller.removeTrack(source: source, trackId: trackId);
      } else {
        final title = widget.playback.title?.trim();

        await controller.saveTrack(
          source: source,
          trackId: trackId,
          title: title == null || title.isEmpty ? trackId : title,
          channelTitle: '',
          thumbnailUrl: widget.playback.thumbnailUrl,
          durationMs: widget.playback.durationMs,
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Failed to update saved tracks: $error')),
        );
    } finally {
      if (mounted) {
        setState(() {
          _changing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final savedState = ref.watch(savedTracksControllerProvider);

    final trackId = widget.playback.trackId?.trim();

    final source = widget.playback.source?.trim();

    final validTrack =
        trackId != null &&
        trackId.isNotEmpty &&
        source != null &&
        source.isNotEmpty;

    final savedTracks = savedState.value;

    final isSaved =
        validTrack &&
        savedTracks != null &&
        savedTracks.any(
          (track) => track.source == source && track.trackId == trackId,
        );

    return IconButton(
      tooltip: isSaved ? 'Remove from saved' : 'Save track',
      onPressed: validTrack && !_changing ? _toggleSaved : null,
      icon: Icon(
        isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      ),
      iconSize: widget.compact ? 23 : 25,
    );
  }
}

// =====================================================================
// EMPTY PLAYER
// =====================================================================

class _EmptyPlayer extends StatelessWidget {
  const _EmptyPlayer();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: colorScheme.surfaceContainer,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.music_note_rounded,
                size: 48,
                color: colorScheme.onSurfaceVariant,
              ),

              const SizedBox(height: 8),

              Text(
                'Nothing playing',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
