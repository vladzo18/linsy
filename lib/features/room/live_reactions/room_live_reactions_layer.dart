import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'room_live_reaction_service.dart';
import 'room_reaction_burst_view.dart';
import 'room_reaction_models.dart';

class RoomLiveReactionsLayer extends ConsumerStatefulWidget {
  const RoomLiveReactionsLayer({required this.roomId, super.key});

  final String roomId;

  @override
  ConsumerState<RoomLiveReactionsLayer> createState() =>
      _RoomLiveReactionsLayerState();
}

class _RoomLiveReactionsLayerState
    extends ConsumerState<RoomLiveReactionsLayer> {
  static const int _maximumVisibleBursts = 8;

  final RoomReactionComboTracker _comboTracker = RoomReactionComboTracker();

  final List<RoomReactionVisualBurst> _activeBursts = [];

  // ===================================================================
  // ROOM
  // ===================================================================

  @override
  void didUpdateWidget(covariant RoomLiveReactionsLayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.roomId == widget.roomId) {
      return;
    }

    _comboTracker.clear();

    _activeBursts.clear();
  }

  // ===================================================================
  // REACTION
  // ===================================================================

  void _handleReaction(RoomLiveReaction reaction) {
    if (!mounted) {
      return;
    }

    final combo = _comboTracker.register(reaction);

    final burst = RoomReactionVisualBurst(
      id:
          '${reaction.id}:'
          '${reaction.reactionId}:'
          '${combo.count}',

      reaction: reaction,

      comboCount: combo.count,
    );

    setState(() {
      // Если combo продолжается —
      // предыдущий эффект того же типа
      // заменяется более сильным.
      if (combo.continues) {
        _activeBursts.removeWhere(
          (existing) => existing.reaction.reactionId == reaction.reactionId,
        );
      }

      while (_activeBursts.length >= _maximumVisibleBursts) {
        _activeBursts.removeAt(0);
      }

      _activeBursts.add(burst);
    });
  }

  // ===================================================================
  // REMOVE
  // ===================================================================

  void _removeBurst(String id) {
    if (!mounted) {
      return;
    }

    setState(() {
      _activeBursts.removeWhere((burst) => burst.id == id);
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

        _handleReaction(reaction);
      },
    );

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              for (final burst in _activeBursts)
                RoomReactionBurstView(
                  key: ValueKey(burst.id),

                  burst: burst,

                  width: constraints.maxWidth,

                  height: constraints.maxHeight,

                  onFinished: () {
                    _removeBurst(burst.id);
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
