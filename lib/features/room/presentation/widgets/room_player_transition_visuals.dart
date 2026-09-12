import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'room_player_overlay_phase.dart';

class TransitionBadge extends StatelessWidget {
  const TransitionBadge({
    super.key,
    required this.phase,
    required this.paused,
    required this.accent,
    required this.compact,
  });

  final PlayerOverlayPhase phase;

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
        case PlayerOverlayPhase.ending:
          icon = Icons.skip_next_rounded;
          text = 'UP NEXT';

        case PlayerOverlayPhase.preparingNext:
          icon = Icons.sync_rounded;
          text = 'PREPARING NEXT';

        case PlayerOverlayPhase.preparingRepeat:
          icon = Icons.replay_rounded;
          text = 'PLAYING AGAIN';

        case PlayerOverlayPhase.none:
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

// STATUS

class TransitionStatus extends StatelessWidget {
  const TransitionStatus({
    super.key,
    required this.phase,
    required this.paused,
    required this.hasNext,
    required this.accent,
    required this.compact,
  });

  final PlayerOverlayPhase phase;

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
        case PlayerOverlayPhase.ending:
          text = hasNext ? 'Starts automatically' : 'Will replay automatically';

        case PlayerOverlayPhase.preparingNext:
          text = 'Synchronizing all devices';

        case PlayerOverlayPhase.preparingRepeat:
          text = 'Synchronizing restart';

        case PlayerOverlayPhase.none:
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

// ARTWORK

class AnimatedArtwork extends StatelessWidget {
  const AnimatedArtwork({
    super.key,
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

// COUNTDOWN ORB

class CountdownOrb extends StatelessWidget {
  const CountdownOrb({
    super.key,
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

// PARTICLES / AMBIENT BACKGROUND

class TransitionAtmospherePainter extends CustomPainter {
  TransitionAtmospherePainter({required this.animation, required this.accent})
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
  bool shouldRepaint(covariant TransitionAtmospherePainter oldDelegate) {
    return oldDelegate.accent != accent;
  }
}

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
