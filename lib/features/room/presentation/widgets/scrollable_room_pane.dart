import 'package:flutter/material.dart';
import 'room_panel_scroll_physics.dart';

class ScrollableRoomPane extends StatelessWidget {
  const ScrollableRoomPane({
    super.key,
    required this.child,
    this.onScrollHandoff,
    this.allowContentScroll = true,
  });

  final Widget child;

  final RoomPanelScrollHandoff? onScrollHandoff;

  final bool allowContentScroll;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SingleChildScrollView(
        physics: roomPanelScrollPhysics(
          onHandoff: onScrollHandoff,
          allowContentScroll: allowContentScroll,
        ),
        padding: const EdgeInsets.all(12),
        child: child,
      ),
    );
  }
}
