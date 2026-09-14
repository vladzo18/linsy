import 'package:flutter/material.dart';

/// A bounded overlay beside the video, shared by room feedback and pickers.
class FeedbackRegion extends StatefulWidget {
  const FeedbackRegion({required this.child, super.key});
  final Widget child;
  static final _regions = Expando<_FeedbackRegionState>();

  static OverlayState? overlayOf(BuildContext context) {
    final region = _regions[Overlay.of(context, rootOverlay: true)];
    if (region == null ||
        !region.mounted ||
        ModalRoute.of(context) != region.route) {
      return null;
    }
    return region.overlayKey.currentState;
  }

  @override
  State<FeedbackRegion> createState() => _FeedbackRegionState();
}

class _FeedbackRegionState extends State<FeedbackRegion> {
  final overlayKey = GlobalKey<OverlayState>();
  OverlayState? root;
  ModalRoute<dynamic>? route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    root = Overlay.of(context, rootOverlay: true);
    route = ModalRoute.of(context);
    FeedbackRegion._regions[root!] = this;
  }

  @override
  void dispose() {
    if (root != null && FeedbackRegion._regions[root!] == this) {
      FeedbackRegion._regions[root!] = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRect(
    child: Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Overlay(key: overlayKey),
      ],
    ),
  );
}
