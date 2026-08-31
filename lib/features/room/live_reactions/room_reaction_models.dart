import 'package:flutter/animation.dart';

import 'room_live_reaction_service.dart';

// =====================================================================
// COMBO TRACKER
// =====================================================================

class RoomReactionComboTracker {
  RoomReactionComboTracker({this.window = const Duration(milliseconds: 900)});

  final Duration window;

  final Map<String, _ComboState> _states = {};

  RoomReactionCombo register(RoomLiveReaction reaction) {
    final now = DateTime.now();

    final previous = _states[reaction.reactionId];

    final continues =
        previous != null && now.difference(previous.lastReactionAt) <= window;

    final count = continues ? previous.count + 1 : 1;

    _states[reaction.reactionId] = _ComboState(
      count: count,
      lastReactionAt: now,
    );

    return RoomReactionCombo(count: count, continues: continues);
  }

  void clear() {
    _states.clear();
  }
}

class _ComboState {
  const _ComboState({required this.count, required this.lastReactionAt});

  final int count;
  final DateTime lastReactionAt;
}

class RoomReactionCombo {
  const RoomReactionCombo({required this.count, required this.continues});

  final int count;
  final bool continues;
}

// =====================================================================
// VISUAL BURST
// =====================================================================

class RoomReactionVisualBurst {
  const RoomReactionVisualBurst({
    required this.id,
    required this.reaction,
    required this.comboCount,
  });

  final String id;

  final RoomLiveReaction reaction;

  final int comboCount;

  /// Визуальную мощность ограничиваем,
  /// даже если combo ушло в x20.
  int get power {
    return comboCount.clamp(1, 8).toInt();
  }
}

// =====================================================================
// PARTICLE
// =====================================================================

class RoomReactionParticle {
  const RoomReactionParticle({
    required this.symbol,
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    required this.size,
    required this.delay,
    required this.rotation,
    required this.curve,
    required this.wobble,
  });

  final String symbol;

  final double startX;
  final double startY;

  final double endX;
  final double endY;

  final double size;

  final double delay;

  final double rotation;

  final Curve curve;

  final double wobble;
}
