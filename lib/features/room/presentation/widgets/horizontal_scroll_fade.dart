import 'package:flutter/material.dart';

/// Hints at offscreen items without fading either end when all items fit.
class HorizontalScrollFade extends StatefulWidget {
  const HorizontalScrollFade({required this.child, super.key});

  final Widget child;

  @override
  State<HorizontalScrollFade> createState() => _HorizontalScrollFadeState();
}

class _HorizontalScrollFadeState extends State<HorizontalScrollFade> {
  bool _left = false;
  bool _right = false;

  void _update(ScrollMetrics metrics) {
    if (metrics.axis != Axis.horizontal) return;
    final reversed = metrics.axisDirection == AxisDirection.left;
    final before = metrics.extentBefore > 1;
    final after = metrics.extentAfter > 1;
    final left = reversed ? after : before;
    final right = reversed ? before : after;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || (_left == left && _right == right)) return;
      setState(() {
        _left = left;
        _right = right;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        theme.cardTheme.color ?? theme.colorScheme.surfaceContainerLow;
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) {
        if (notification.depth == 0) _update(notification.metrics);
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.depth == 0) _update(notification.metrics);
          return false;
        },
        child: Stack(
          children: [
            widget.child,
            for (final left in [true, false])
              if (left ? _left : _right)
                Positioned(
                  key: ValueKey(
                    left ? 'scroll-fade-left' : 'scroll-fade-right',
                  ),
                  left: left ? 0 : null,
                  right: left ? null : 0,
                  top: 0,
                  bottom: 0,
                  width: 20,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: left
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                          end: left
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          colors: [color, color.withValues(alpha: 0)],
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
}
