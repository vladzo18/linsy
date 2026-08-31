import 'dart:math' as math;

import 'package:flutter/animation.dart';

import 'room_live_reaction_service.dart';
import 'room_reaction_models.dart';

class RoomReactionEffectFactory {
  RoomReactionEffectFactory({
    required this.burst,
    required this.width,
    required this.height,
  }) : _random = math.Random(burst.id.hashCode);

  final RoomReactionVisualBurst burst;

  final double width;
  final double height;

  final math.Random _random;

  // ===================================================================
  // HELPERS
  // ===================================================================

  int get _power => burst.power;

  String get _reactionId => burst.reaction.reactionId;

  double get _comboScale {
    return 1 + (_power - 1) * 0.07;
  }

  double get _spreadFactor {
    return math.min(0.30 + (_power - 1) * 0.065, 0.75);
  }

  Duration get duration {
    return Duration(
      milliseconds: switch (_reactionId) {
        'skull' => 1900,
        'clap' => 2450,
        'laugh' => 2200,
        _ => 2450,
      },
    );
  }

  // ===================================================================
  // CREATE
  // ===================================================================

  List<RoomReactionParticle> createParticles() {
    return switch (_reactionId) {
      'fire' => _createFire(),
      'love' => _createLove(),
      'laugh' => _createLaugh(),
      'cry' => _createCry(),
      'skull' => _createSkull(),
      'clap' => _createClap(),
      _ => _createGeneric(),
    };
  }

  // ===================================================================
  // FIRE
  // ===================================================================

  List<RoomReactionParticle> _createFire() {
    final count = 5 + _power * 6;

    final spread = width * _spreadFactor;

    final center = width * 0.5;

    return List.generate(count, (index) {
      final spark = index % 4 == 0;

      final startX = center - spread + _random.nextDouble() * spread * 2;

      final startY = height * (0.72 + _random.nextDouble() * 0.24);

      final travel =
          height * (0.44 + _random.nextDouble() * (0.22 + _power * 0.025));

      return RoomReactionParticle(
        symbol: spark ? '✨' : '🔥',

        startX: startX,

        startY: startY,

        endX: startX + (-width * 0.07 + _random.nextDouble() * width * 0.14),

        endY: startY - travel,

        size: spark
            ? 20 + _random.nextDouble() * 22
            : (32 + _random.nextDouble() * 34) * _comboScale,

        delay: _random.nextDouble() * 0.18,

        rotation: -0.38 + _random.nextDouble() * 0.76,

        curve: Curves.easeOutCubic,

        wobble: 15 + _random.nextDouble() * 34,
      );
    });
  }

  // ===================================================================
  // LOVE
  // ===================================================================

  List<RoomReactionParticle> _createLove() {
    final count = 5 + _power * 5;

    const symbols = ['💖', '💕', '💗', '💞', '✨'];

    final result = <RoomReactionParticle>[];

    for (var index = 0; index < count; index++) {
      final edge = _power >= 3 ? index % 4 : index % 2;

      late double startX;
      late double startY;

      if (edge == 0) {
        // LEFT
        startX = -40;

        startY = height * (0.15 + _random.nextDouble() * 0.70);
      } else if (edge == 1) {
        // RIGHT
        startX = width + 40;

        startY = height * (0.15 + _random.nextDouble() * 0.70);
      } else if (edge == 2) {
        // TOP
        startX = width * (0.10 + _random.nextDouble() * 0.80);

        startY = -40;
      } else {
        // BOTTOM
        startX = width * (0.10 + _random.nextDouble() * 0.80);

        startY = height + 40;
      }

      result.add(
        RoomReactionParticle(
          symbol: index == 0 ? '😍' : symbols[_random.nextInt(symbols.length)],

          startX: startX,

          startY: startY,

          endX: width * (0.25 + _random.nextDouble() * 0.50),

          endY: height * (0.12 + _random.nextDouble() * 0.48),

          size: index == 0
              ? 72 + _power * 8
              : (27 + _random.nextDouble() * 32) * _comboScale,

          delay: _random.nextDouble() * 0.22,

          rotation: -0.55 + _random.nextDouble() * 1.10,

          curve: Curves.easeOutBack,

          wobble: 7 + _random.nextDouble() * 23,
        ),
      );
    }

    return result;
  }

  // ===================================================================
  // LAUGH
  // ===================================================================

  List<RoomReactionParticle> _createLaugh() {
    final count = 4 + _power * 4;

    return List.generate(count, (index) {
      final startX = width * (0.05 + _random.nextDouble() * 0.90);

      final startY = height * (0.66 + _random.nextDouble() * 0.28);

      return RoomReactionParticle(
        symbol: index % 3 == 0 ? '🤣' : '😂',

        startX: startX,

        startY: startY,

        endX: width * (0.03 + _random.nextDouble() * 0.94),

        endY: height * (0.06 + _random.nextDouble() * 0.46),

        size: (37 + _random.nextDouble() * 38) * _comboScale,

        delay: _random.nextDouble() * 0.17,

        rotation: (-1.1 + _random.nextDouble() * 2.2) * _comboScale,

        curve: Curves.elasticOut,

        wobble: 18 + _random.nextDouble() * (25 + _power * 4),
      );
    });
  }

  // ===================================================================
  // CRY
  // ===================================================================

  List<RoomReactionParticle> _createCry() {
    final rainCount = 6 + _power * 6;

    final particles = <RoomReactionParticle>[
      RoomReactionParticle(
        symbol: '😭',

        startX: width * 0.5,

        startY: height * 0.62,

        endX: width * 0.5,

        endY: height * 0.30,

        size: 76 + _power * 10,

        delay: 0,

        rotation: 0,

        curve: Curves.easeOutBack,

        wobble: 6 + _power * 2,
      ),
    ];

    for (var index = 0; index < rainCount; index++) {
      final x = width * (0.02 + _random.nextDouble() * 0.96);

      particles.add(
        RoomReactionParticle(
          symbol: index % 9 == 0 ? '😢' : '💧',

          startX: x,

          startY: -40 - _random.nextDouble() * height * 0.35,

          endX: x + (-30 + _random.nextDouble() * 60),

          endY: height * (0.70 + _random.nextDouble() * 0.35),

          size: index % 9 == 0
              ? 35 * _comboScale
              : (20 + _random.nextDouble() * 21) * _comboScale,

          delay: _random.nextDouble() * 0.20,

          rotation: -0.20 + _random.nextDouble() * 0.40,

          curve: Curves.easeIn,

          wobble: 3 + _random.nextDouble() * 5,
        ),
      );
    }

    return particles;
  }

  // ===================================================================
  // SKULL
  // ===================================================================

  List<RoomReactionParticle> _createSkull() {
    final satellites = 3 + _power * 3;

    final centerX = width * 0.5;

    final centerY = height * 0.47;

    final result = <RoomReactionParticle>[
      RoomReactionParticle(
        symbol: '💀',

        startX: centerX,
        startY: centerY,

        endX: centerX,
        endY: centerY - 25,

        size: 92 + _power * 18,

        delay: 0,

        rotation: 0,

        curve: Curves.easeOutBack,

        wobble: 7 + _power * 2,
      ),
    ];

    for (var index = 0; index < satellites; index++) {
      final angle =
          math.pi * 2 * index / satellites + _random.nextDouble() * 0.25;

      final distance = math.min(width, height) * (0.18 + _power * 0.035);

      result.add(
        RoomReactionParticle(
          symbol: index.isEven ? '💀' : '✨',

          startX: centerX,
          startY: centerY,

          endX: centerX + math.cos(angle) * distance,

          endY: centerY + math.sin(angle) * distance,

          size: (26 + _random.nextDouble() * 29) * _comboScale,

          delay: 0.03 + _random.nextDouble() * 0.08,

          rotation: -1.2 + _random.nextDouble() * 2.4,

          curve: Curves.easeOutCubic,

          wobble: 0,
        ),
      );
    }

    return result;
  }

  // ===================================================================
  // CLAP
  // ===================================================================

  List<RoomReactionParticle> _createClap() {
    final clapCount = switch (_power) {
      1 => 5,
      2 => 7,
      3 => 9,
      4 => 12,
      5 => 15,
      6 => 18,
      7 => 21,
      _ => 24,
    };

    final particles = <RoomReactionParticle>[];

    for (var index = 0; index < clapCount; index++) {
      // ===============================================================
      // DISTRIBUTION
      //
      // Делим экран примерно на полосы,
      // чтобы все 👏 не собрались случайно
      // в одном углу.
      // ===============================================================

      final normalizedX = (index + 0.5) / clapCount;

      final shuffledX = (normalizedX + (-0.08 + _random.nextDouble() * 0.16))
          .clamp(0.06, 0.94);

      final targetX = width * shuffledX;

      final targetY = height * (0.20 + _random.nextDouble() * 0.55);

      // ===============================================================
      // START
      //
      // Emoji приходит немного снизу и сбоку,
      // потом резко "хлопает" в своей точке.
      // ===============================================================

      final direction = index.isEven ? -1.0 : 1.0;

      final startX =
          targetX + direction * width * (0.025 + _random.nextDouble() * 0.055);

      final startY = targetY + height * (0.10 + _random.nextDouble() * 0.10);

      // ===============================================================
      // RHYTHM
      // 👏   👏    👏   👏...
      // ===============================================================

      final sequence = index / clapCount;

      final delay = sequence * 0.44 + _random.nextDouble() * 0.025;

      final size = (44 + _random.nextDouble() * 30) * _comboScale;

      particles.add(
        RoomReactionParticle(
          symbol: '👏',

          startX: startX,
          startY: startY,

          endX: targetX + (-10 + _random.nextDouble() * 20),

          endY: targetY - 18 - _random.nextDouble() * 28,

          size: size,

          delay: delay,

          rotation: direction * (0.28 + _random.nextDouble() * 0.42),

          curve: Curves.elasticOut,

          wobble: 16 + _random.nextDouble() * 24,
        ),
      );

      // ===============================================================
      // SPARK
      // ===============================================================

      if (index.isEven) {
        particles.add(
          RoomReactionParticle(
            symbol: '✨',

            startX: targetX,
            startY: targetY,

            endX: targetX + (-22 + _random.nextDouble() * 44),

            endY: targetY - 35 - _random.nextDouble() * 38,

            size: 20 + _random.nextDouble() * 17,

            delay: (delay + 0.035).clamp(0.0, 0.92),

            rotation: -0.8 + _random.nextDouble() * 1.6,

            curve: Curves.easeOutBack,

            wobble: 5 + _random.nextDouble() * 8,
          ),
        );
      }
    }

    return particles;
  }

  // ===================================================================
  // GENERIC
  // ===================================================================

  List<RoomReactionParticle> _createGeneric() {
    final definition = roomLiveReactionDefinitionById(_reactionId);

    return [
      RoomReactionParticle(
        symbol: definition?.emoji ?? '✨',

        startX: width * 0.5,

        startY: height * 0.72,

        endX: width * 0.5,

        endY: height * 0.18,

        size: 75 + _power * 10,

        delay: 0,

        rotation: 0,

        curve: Curves.easeOutBack,

        wobble: 20,
      ),
    ];
  }
}
