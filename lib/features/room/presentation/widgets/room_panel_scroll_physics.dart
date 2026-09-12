import 'package:flutter/material.dart';

typedef RoomPanelScrollHandoff =
    bool Function(double dragDelta, ScrollMetrics metrics);

// Scrollable refreshes its ScrollPosition when the physics TYPE changes, not
// when a field changes. Use a separate type while the panel owns the gesture.
ScrollPhysics roomPanelScrollPhysics({
  required RoomPanelScrollHandoff? onHandoff,
  required bool allowContentScroll,
}) {
  return allowContentScroll
      ? RoomPanelScrollPhysics(onHandoff: onHandoff, allowContentScroll: true)
      : const NeverScrollableScrollPhysics();
}

class RoomPanelScrollPhysics extends ClampingScrollPhysics {
  const RoomPanelScrollPhysics({
    required this.onHandoff,
    required this.allowContentScroll,
    super.parent,
  });

  final RoomPanelScrollHandoff? onHandoff;
  final bool allowContentScroll;

  @override
  RoomPanelScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return RoomPanelScrollPhysics(
      onHandoff: onHandoff,
      allowContentScroll: allowContentScroll,
      parent: buildParent(ancestor),
    );
  }

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) {
    // Expanded panel должен принимать
    // gesture даже когда контента мало:
    // это нужно для swipe-down handoff.
    return allowContentScroll;
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    if (!allowContentScroll) {
      return 0;
    }

    final atTop = position.pixels <= position.minScrollExtent + 1;

    // Downward movement can collapse the panel only at the top. Upward
    // movement is offered so the panel can reverse an active handoff;
    // otherwise the callback returns false and the list scrolls normally.
    if ((offset < 0 || atTop) && onHandoff != null) {
      final consumed = onHandoff!(offset, position);

      if (consumed) {
        return 0;
      }
    }

    return super.applyPhysicsToUserOffset(position, offset);
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (!allowContentScroll) {
      return null;
    }

    return super.createBallisticSimulation(position, velocity);
  }
}
