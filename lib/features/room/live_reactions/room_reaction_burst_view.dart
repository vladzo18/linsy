import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'room_live_reaction_service.dart';
import 'room_reaction_effect_factory.dart';
import 'room_reaction_models.dart';

class RoomReactionBurstView extends StatefulWidget {
  const RoomReactionBurstView({
    required this.burst,
    required this.width,
    required this.height,
    required this.onFinished,
    super.key,
  });

  final RoomReactionVisualBurst burst;

  final double width;
  final double height;

  final VoidCallback onFinished;

  @override
  State<RoomReactionBurstView> createState() => _RoomReactionBurstViewState();
}

class _RoomReactionBurstViewState extends State<RoomReactionBurstView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final List<RoomReactionParticle> _particles;

  // ===================================================================
  // HELPERS
  // ===================================================================

  int get _combo => widget.burst.comboCount;

  int get _power => widget.burst.power;

  String get _reactionId => widget.burst.reaction.reactionId;

  // ===================================================================
  // INIT
  // ===================================================================

  @override
  void initState() {
    super.initState();

    final factory = RoomReactionEffectFactory(
      burst: widget.burst,
      width: widget.width,
      height: widget.height,
    );

    _particles = factory.createParticles();

    _controller = AnimationController(vsync: this, duration: factory.duration);

    _controller.addStatusListener(_handleAnimationStatus);

    _controller.forward();
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onFinished();
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_handleAnimationStatus);

    _controller.dispose();

    super.dispose();
  }

  // ===================================================================
  // BUILD
  // ===================================================================

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = _controller.value;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              if (_combo >= 2)
                _ComboImpact(
                  burstId: widget.burst.id,
                  progress: progress,
                  comboCount: _combo,
                  width: widget.width,
                  height: widget.height,
                ),

              if (_reactionId == 'skull')
                _SkullShockwave(
                  progress: progress,
                  width: widget.width,
                  height: widget.height,
                  power: _power,
                ),

              for (final particle in _particles)
                _ParticleView(particle: particle, progress: progress),

              if (_ComboCalloutPolicy.shouldShow(_combo))
                _ComboCallout(
                  burstId: widget.burst.id,

                  reactionId: _reactionId,

                  count: _combo,

                  progress: progress,

                  width: widget.width,

                  height: widget.height,
                ),
            ],
          );
        },
      ),
    );
  }
}

// =====================================================================
// PARTICLE
// =====================================================================

class _ParticleView extends StatelessWidget {
  const _ParticleView({required this.particle, required this.progress});

  final RoomReactionParticle particle;

  final double progress;

  @override
  Widget build(BuildContext context) {
    final usable = 1 - particle.delay;

    if (usable <= 0) {
      return const SizedBox.shrink();
    }

    final rawT = ((progress - particle.delay) / usable).clamp(0.0, 1.0);

    if (rawT <= 0) {
      return const SizedBox.shrink();
    }

    final movement = particle.curve.transform(rawT);

    final x =
        particle.startX +
        (particle.endX - particle.startX) * movement +
        math.sin(rawT * math.pi * 2.3) * particle.wobble;

    final y = particle.startY + (particle.endY - particle.startY) * movement;

    final popT = (rawT / 0.15).clamp(0.0, 1.0);

    final scale = 0.28 + Curves.easeOutBack.transform(popT) * 0.86;

    const fadeStart = 0.72;

    final opacity = rawT <= fadeStart
        ? 1.0
        : (1 - (rawT - fadeStart) / (1 - fadeStart)).clamp(0.0, 1.0);

    return Positioned(
      left: x - particle.size / 2,

      top: y - particle.size / 2,

      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: particle.rotation * movement,

          child: Transform.scale(
            scale: scale,

            child: Text(
              particle.symbol,

              style: TextStyle(fontSize: particle.size, height: 1),
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// COMBO PLACEMENT
// =====================================================================

class _ComboPlacement {
  const _ComboPlacement._();

  /// Нормализованные координаты 0..1.
  ///
  /// Это уже не Alignment.
  /// И круг, и текст получают буквально один Offset.
  static const anchors = [
    Offset(0.24, 0.28),
    Offset(0.76, 0.32),
    Offset(0.26, 0.54),
    Offset(0.74, 0.58),
    Offset(0.36, 0.18),
    Offset(0.64, 0.20),
  ];

  static const rotations = [-0.08, 0.07, -0.06, 0.08, -0.04, 0.05];

  static int slotFor(String burstId) {
    final hash = burstId.hashCode & 0x7fffffff;

    return hash % anchors.length;
  }

  static Offset anchorFor({
    required String burstId,
    required double width,
    required double height,
  }) {
    final normalized = anchors[slotFor(burstId)];

    return Offset(width * normalized.dx, height * normalized.dy);
  }

  static double rotationFor(String burstId) {
    return rotations[slotFor(burstId)];
  }
}

// =====================================================================
// COMBO CALLOUT POLICY
// =====================================================================

class _ComboCalloutPolicy {
  const _ComboCalloutPolicy._();

  static bool shouldShow(int count) {
    if (count == 2 || count == 3 || count == 5 || count == 8) {
      return true;
    }

    // После x10 показываем только milestones.
    if (count >= 10 && count % 5 == 0) {
      return true;
    }

    return false;
  }

  static bool usePhrase(int count) {
    if (count == 5) {
      return true;
    }

    if (count >= 10 && count % 10 == 0) {
      return true;
    }

    return false;
  }

  static String text({
    required String reactionId,
    required String emoji,
    required int count,
  }) {
    if (!usePhrase(count)) {
      final suffix = count >= 8 ? '!' : '';

      return count.isEven ? '$emoji ×$count$suffix' : '×$count $emoji$suffix';
    }

    return switch (reactionId) {
      'fire' => '🔥 ON FIRE!',
      'love' => '💖 SO MUCH LOVE!',
      'laugh' => '😂 LOL!',
      'cry' => '😭 WATERWORKS!',
      'skull' => '💀 RIP!',
      'clap' => '👏 APPLAUSE!',
      _ => '$emoji ×$count!',
    };
  }
}

// =====================================================================
// COMBO CALLOUT
// =====================================================================

class _ComboCallout extends StatelessWidget {
  const _ComboCallout({
    required this.burstId,
    required this.reactionId,
    required this.count,
    required this.progress,
    required this.width,
    required this.height,
  });

  final String burstId;

  final String reactionId;

  final int count;

  final double progress;

  final double width;

  final double height;

  @override
  Widget build(BuildContext context) {
    final definition = roomLiveReactionDefinitionById(reactionId);

    if (definition == null) {
      return const SizedBox.shrink();
    }

    final anchor = _ComboPlacement.anchorFor(
      burstId: burstId,
      width: width,
      height: height,
    );

    final rotation = _ComboPlacement.rotationFor(burstId);
    // ===============================================================
    // ENTER
    //
    // Чуть быстрее появляется.
    // ===============================================================

    final enter = Curves.easeOutBack.transform(
      (progress / 0.13).clamp(0.0, 1.0),
    );

    // ===============================================================
    // FADE
    //
    // Раньше fade начинался уже на 52%.
    //
    // Теперь callout почти 3/4 анимации
    // остаётся полностью видимым.
    // ===============================================================

    final opacity = progress <= 0.72
        ? 1.0
        : (1 - (progress - 0.72) / 0.28).clamp(0.0, 1.0);

    final phrase = _ComboCalloutPolicy.usePhrase(count);

    final text = _ComboCalloutPolicy.text(
      reactionId: reactionId,
      emoji: definition.emoji,
      count: count,
    );

    // ===============================================================
    // SIZE
    // ===============================================================

    final fontSize = phrase ? 46.0 : 33.0 + count.clamp(2, 8).toDouble() * 2.2;

    final targetScale = phrase ? 1.18 : 1.06;

    final colors = Theme.of(context).colorScheme;

    return Positioned(
      left: anchor.dx,
      top: anchor.dy,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: Opacity(
          opacity: opacity,
          child: Transform.rotate(
            angle: rotation,
            child: Transform.scale(
              scale: 0.35 + enter * (targetScale - 0.35),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: math.min(width * 0.55, 360),
                ),
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    shadows: [
                      Shadow(
                        color: colors.shadow.withValues(alpha: 0.82),
                        blurRadius: 22,
                        offset: const Offset(0, 4),
                      ),
                      Shadow(
                        color: colors.primary.withValues(alpha: 0.32),
                        blurRadius: 28,
                        offset: Offset.zero,
                      ),
                    ],
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

// =====================================================================
// COMBO IMPACT
// =====================================================================

class _ComboImpact extends StatelessWidget {
  const _ComboImpact({
    required this.burstId,
    required this.progress,
    required this.comboCount,
    required this.width,
    required this.height,
  });

  final String burstId;

  final double progress;

  final int comboCount;

  final double width;

  final double height;

  @override
  Widget build(BuildContext context) {
    final t = (progress / 0.24).clamp(0.0, 1.0);

    if (t >= 1) {
      return const SizedBox.shrink();
    }

    final power = comboCount.clamp(1, 8);

    final movement = Curves.easeOutCubic.transform(t);

    final base = math.min(width, height);

    final size = 90 + base * (0.20 + power * 0.045) * movement;

    final opacity = ((1 - t) * (0.08 + power * 0.025)).clamp(0.0, 0.30);

    final colors = Theme.of(context).colorScheme;

    final anchor = _ComboPlacement.anchorFor(
      burstId: burstId,
      width: width,
      height: height,
    );

    return Stack(
      children: [
        // =========================================================
        // SOFT FULL-SCREEN FLASH
        //
        // Его оставляем глобальным.
        // =========================================================
        Positioned.fill(
          child: Opacity(
            opacity: opacity * 0.32,
            child: ColoredBox(color: colors.primary),
          ),
        ),

        // =========================================================
        // LOCAL IMPACT
        // =========================================================
        Positioned(
          left: anchor.dx - size / 2,
          top: anchor.dy - size / 2,
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.primary,
                  width: 2 + power * 0.35,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =====================================================================
// SKULL SHOCKWAVE
// =====================================================================

class _SkullShockwave extends StatelessWidget {
  const _SkullShockwave({
    required this.progress,
    required this.width,
    required this.height,
    required this.power,
  });

  final double progress;

  final double width;
  final double height;

  final int power;

  @override
  Widget build(BuildContext context) {
    final t = (progress / 0.60).clamp(0.0, 1.0);

    if (t >= 1) {
      return const SizedBox.shrink();
    }

    final movement = Curves.easeOutCubic.transform(t);

    final base = math.min(width, height);

    final maximumSize = base * (0.58 + power * 0.07);

    final size = 60 + maximumSize * movement;

    final opacity = (1 - t) * 0.55;

    final colors = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Positioned(
          left: width / 2 - size / 2,

          top: height * 0.47 - size / 2,

          child: Opacity(
            opacity: opacity,

            child: Container(
              width: size,
              height: size,

              decoration: BoxDecoration(
                shape: BoxShape.circle,

                border: Border.all(
                  color: colors.primary,

                  width: 3 + power * 0.45,
                ),
              ),
            ),
          ),
        ),

        if (power >= 4)
          Positioned(
            left: width / 2 - size * 0.34,

            top: height * 0.47 - size * 0.34,

            child: Opacity(
              opacity: opacity * 0.72,

              child: Container(
                width: size * 0.68,

                height: size * 0.68,

                decoration: BoxDecoration(
                  shape: BoxShape.circle,

                  border: Border.all(color: colors.primary, width: 2),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
