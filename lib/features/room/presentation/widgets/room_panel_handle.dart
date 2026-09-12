import 'package:flutter/material.dart';

/// Always accessible independently of the position of the inner list.
class RoomPanelHandle extends StatelessWidget {
  const RoomPanelHandle({
    required this.expanded,
    required this.keyboardVisible,
    required this.onTap,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    super.key,
  });

  final bool expanded;
  final bool keyboardVisible;
  final VoidCallback onTap;
  final GestureDragStartCallback? onDragStart;
  final GestureDragUpdateCallback? onDragUpdate;
  final GestureDragEndCallback? onDragEnd;

  @override
  Widget build(BuildContext context) {
    final label = keyboardVisible
        ? 'Hide keyboard'
        : expanded
        ? 'Collapse'
        : 'Expand';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: keyboardVisible ? null : onDragStart,
      onVerticalDragUpdate: keyboardVisible ? null : onDragUpdate,
      onVerticalDragEnd: keyboardVisible ? null : onDragEnd,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: const RoundedRectangleBorder(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              keyboardVisible
                  ? Icons.keyboard_hide_rounded
                  : expanded
                  ? Icons.keyboard_arrow_down_rounded
                  : Icons.keyboard_arrow_up_rounded,
            ),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
      ),
    );
  }
}
