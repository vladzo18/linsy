import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Reports natural content size after layout, including later text reflows.
class MeasuredContent extends SingleChildRenderObjectWidget {
  const MeasuredContent({
    required this.onSize,
    required super.child,
    super.key,
  });

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) => _MeasuredBox(onSize);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderProxyBox renderObject,
  ) {
    (renderObject as _MeasuredBox).onSize = onSize;
  }
}

class _MeasuredBox extends RenderProxyBox {
  _MeasuredBox(this.onSize);
  ValueChanged<Size> onSize;
  Size? _reported;

  @override
  void performLayout() {
    super.performLayout();
    if (_reported == size) return;
    _reported = size;
    final measured = size;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached) onSize(measured);
    });
  }
}
