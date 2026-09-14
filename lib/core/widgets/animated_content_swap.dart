import 'package:flutter/material.dart';

/// Slides bounded panel contents past one another without moving the panel.
class AnimatedContentSwap extends StatelessWidget {
  const AnimatedContentSwap({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) => AnimatedBuilder(
        animation: animation,
        builder: (context, _) => IgnorePointer(
          ignoring: animation.status == AnimationStatus.reverse,
          child: FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.08, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
        ),
      ),
      child: child,
    ),
  );
}
