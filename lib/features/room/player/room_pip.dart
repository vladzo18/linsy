import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final roomPipProvider = NotifierProvider<RoomPip, bool>(RoomPip.new);

class RoomPip extends Notifier<bool> {
  static const _channel = MethodChannel('linsy/pip');
  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  bool build() {
    if (_supported) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'changed') state = call.arguments == true;
      });
      ref.onDispose(() => _channel.setMethodCallHandler(null));
    }
    return false;
  }

  Future<void> configure(bool enabled) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('configure', {'enabled': enabled});
    } on PlatformException catch (error) {
      debugPrint('PiP configuration failed: $error');
    } on MissingPluginException {
      debugPrint('PiP requires a full Android rebuild.');
    }
  }
}
