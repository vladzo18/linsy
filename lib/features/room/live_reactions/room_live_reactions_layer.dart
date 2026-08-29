import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'room_live_reaction_service.dart';

class RoomLiveReactionsLayer extends ConsumerStatefulWidget {
  const RoomLiveReactionsLayer({required this.roomId, super.key});

  final String roomId;

  @override
  ConsumerState<RoomLiveReactionsLayer> createState() =>
      _RoomLiveReactionsLayerState();
}

class _RoomLiveReactionsLayerState
    extends ConsumerState<RoomLiveReactionsLayer> {
  static const int _maximumVisibleReactions = 12;

  final List<RoomLiveReaction> _activeReactions = [];

  // ===================================================================
  // ROOM CHANGED
  // ===================================================================

  @override
  void didUpdateWidget(covariant RoomLiveReactionsLayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.roomId == widget.roomId) {
      return;
    }

    _activeReactions.clear();
  }

  // ===================================================================
  // ADD
  // ===================================================================

  void _showReaction(RoomLiveReaction reaction) {
    if (!mounted) {
      return;
    }

    setState(() {
      _activeReactions.removeWhere((existing) => existing.id == reaction.id);

      while (_activeReactions.length >= _maximumVisibleReactions) {
        _activeReactions.removeAt(0);
      }

      _activeReactions.add(reaction);
    });
  }

  // ===================================================================
  // REMOVE
  // ===================================================================

  void _removeReaction(String id) {
    if (!mounted) {
      return;
    }

    setState(() {
      _activeReactions.removeWhere((reaction) => reaction.id == id);
    });
  }

  // ===================================================================
  // BUILD
  // ===================================================================

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<RoomLiveReaction>>(
      roomLiveReactionStreamProvider(widget.roomId),
      (previous, next) {
        final reaction = next.value;

        if (reaction == null) {
          return;
        }

        if (previous?.value?.id == reaction.id) {
          return;
        }

        _showReaction(reaction);
      },
    );

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (final reaction in _activeReactions)
                _RoomReactionBurst(
                  key: ValueKey(reaction.id),
                  reaction: reaction,
                  maxWidth: constraints.maxWidth,
                  maxHeight: constraints.maxHeight,
                  onFinished: () {
                    _removeReaction(reaction.id);
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

// =====================================================================
// BURST
// =====================================================================

class _RoomReactionBurst extends StatefulWidget {
  const _RoomReactionBurst({
    required this.reaction,
    required this.maxWidth,
    required this.maxHeight,
    required this.onFinished,
    super.key,
  });

  final RoomLiveReaction reaction;

  final double maxWidth;
  final double maxHeight;

  final VoidCallback onFinished;

  @override
  State<_RoomReactionBurst> createState() => _RoomReactionBurstState();
}

class _RoomReactionBurstState extends State<_RoomReactionBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final List<_ReactionParticle> _particles;

  late final double _originX;
  late final double _originY;

  late final bool _showShockwave;

  // ===================================================================
  // INIT
  // ===================================================================

  @override
  void initState() {
    super.initState();

    final random = math.Random(widget.reaction.id.hashCode);

    // ===============================================================
    // ORIGIN
    //
    // Центральная точка тоже может заметно гулять
    // по комнате.
    // ===============================================================

    _originX = widget.maxWidth * (0.20 + random.nextDouble() * 0.60);

    _originY = widget.maxHeight * (0.72 + random.nextDouble() * 0.12);

    _showShockwave = widget.reaction.reactionId == 'skull';

    _particles = _createParticles(random, widget.reaction.reactionId);

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2400 + random.nextInt(350)),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onFinished();
      }
    });

    _controller.forward();
  }

  // ===================================================================
  // PARTICLES
  // ===================================================================

  List<_ReactionParticle> _createParticles(
    math.Random random,
    String reactionId,
  ) {
    final symbols = _symbolsForReaction(reactionId);

    final particles = <_ReactionParticle>[];

    final horizontalSpread = widget.maxWidth * 0.48;

    final normalVerticalTravel = widget.maxHeight * 0.62;

    // ===============================================================
    // MAIN
    // ===============================================================

    particles.add(
      _ReactionParticle(
        symbol: symbols.first,

        offsetX:
            -widget.maxWidth * 0.08 +
            random.nextDouble() * widget.maxWidth * 0.16,

        travelY: widget.maxHeight * (0.48 + random.nextDouble() * 0.18),

        size: 74 + random.nextDouble() * 24,

        rotation: -0.12 + random.nextDouble() * 0.24,

        delay: 0,

        sway: widget.maxWidth * (0.025 + random.nextDouble() * 0.025),

        phase: random.nextDouble() * math.pi * 2,
      ),
    );

    // ===============================================================
    // SECONDARY
    // ===============================================================

    for (var index = 1; index < symbols.length; index++) {
      final symbol = symbols[index];

      final isDrop = symbol == '💧';

      particles.add(
        _ReactionParticle(
          symbol: symbol,

          offsetX:
              -horizontalSpread + random.nextDouble() * horizontalSpread * 2,

          travelY: isDrop
              ? -widget.maxHeight * (0.12 + random.nextDouble() * 0.20)
              : normalVerticalTravel * (0.72 + random.nextDouble() * 0.42),

          size: 30 + random.nextDouble() * 38,

          rotation: -0.70 + random.nextDouble() * 1.40,

          delay: 0.02 + random.nextDouble() * 0.20,

          sway: widget.maxWidth * (0.015 + random.nextDouble() * 0.05),

          phase: random.nextDouble() * math.pi * 2,
        ),
      );
    }

    return particles;
  }

  // ===================================================================
  // DISPOSE
  // ===================================================================

  @override
  void dispose() {
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
          final t = _controller.value;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              if (_showShockwave) _buildShockwave(context, t),

              for (final particle in _particles) _buildParticle(particle, t),
            ],
          );
        },
      ),
    );
  }

  // ===================================================================
  // PARTICLE
  // ===================================================================

  Widget _buildParticle(_ReactionParticle particle, double globalT) {
    final denominator = 1 - particle.delay;

    final rawT = denominator <= 0
        ? 1.0
        : ((globalT - particle.delay) / denominator).clamp(0.0, 1.0);

    if (rawT <= 0) {
      return const SizedBox.shrink();
    }

    final movement = Curves.easeOutCubic.transform(rawT);

    // ===============================================================
    // HORIZONTAL
    // ===============================================================

    final sway =
        math.sin(rawT * math.pi * 2.4 + particle.phase) * particle.sway;

    var x = _originX + particle.offsetX * movement + sway;

    // Не позволяем частице полностью улететь
    // за границу комнаты.
    x = x.clamp(
      particle.size * 0.45,
      math.max(particle.size * 0.45, widget.maxWidth - particle.size * 0.45),
    );

    // ===============================================================
    // VERTICAL
    // ===============================================================

    final y = _originY - particle.travelY * movement;

    // ===============================================================
    // POP
    // ===============================================================

    final popT = (rawT / 0.16).clamp(0.0, 1.0);

    final pop = Curves.easeOutBack.transform(popT);

    var scale = 0.30 + pop * 0.82;

    scale += math.sin(rawT * math.pi * 2) * 0.045;

    // ===============================================================
    // FADE
    // ===============================================================

    const fadeStart = 0.72;

    final opacity = rawT <= fadeStart
        ? 1.0
        : (1 - (rawT - fadeStart) / (1 - fadeStart)).clamp(0.0, 1.0);

    // ===============================================================
    // SKULL SHAKE
    // ===============================================================

    var shake = 0.0;

    if (widget.reaction.reactionId == 'skull' &&
        identical(particle, _particles.first)) {
      shake = math.sin(rawT * math.pi * 26) * 9 * (1 - rawT);
    }

    return Positioned(
      left: x - particle.size / 2 + shake,
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

  // ===================================================================
  // SHOCKWAVE
  // ===================================================================

  Widget _buildShockwave(BuildContext context, double t) {
    final localT = (t / 0.55).clamp(0.0, 1.0);

    if (localT >= 1) {
      return const SizedBox.shrink();
    }

    final progress = Curves.easeOutCubic.transform(localT);

    final maximumSize = math.min(
      widget.maxWidth * 0.75,
      widget.maxHeight * 0.75,
    );

    final size = 70 + maximumSize * progress;

    final opacity = (1 - localT) * 0.46;

    final color = Theme.of(context).colorScheme.primary;

    return Positioned(
      left: _originX - size / 2,
      top: _originY - size / 2,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// PARTICLE
// =====================================================================

class _ReactionParticle {
  const _ReactionParticle({
    required this.symbol,
    required this.offsetX,
    required this.travelY,
    required this.size,
    required this.rotation,
    required this.delay,
    required this.sway,
    required this.phase,
  });

  final String symbol;

  final double offsetX;
  final double travelY;

  final double size;
  final double rotation;
  final double delay;
  final double sway;
  final double phase;
}

// =====================================================================
// PRESETS
// =====================================================================

List<String> _symbolsForReaction(String reactionId) {
  switch (reactionId) {
    case 'fire':
      return const [
        '🔥',
        '🔥',
        '🔥',
        '✨',
        '🔥',
        '✨',
        '🔥',
        '🔥',
        '✨',
        '🔥',
        '🔥',
      ];

    case 'love':
      return const ['😍', '💖', '💕', '💗', '✨', '💖', '💕', '💗', '✨'];

    case 'laugh':
      return const ['😂', '😂', '🤣', '✨', '😂', '🤣', '😂', '✨'];

    case 'cry':
      return const ['😭', '💧', '💧', '😢', '💧', '💧', '💧', '😢', '💧'];

    case 'skull':
      return const ['💀', '💀', '✨', '💀', '✨', '💀', '✨'];

    case 'clap':
      return const ['👏', '👏', '✨', '👏', '✨', '👏', '✨', '👏', '👏'];

    default:
      final definition = roomLiveReactionDefinitionById(reactionId);

      return [definition?.emoji ?? '✨'];
  }
}
