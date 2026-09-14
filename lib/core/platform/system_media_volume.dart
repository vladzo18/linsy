import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final systemMediaVolumeProvider = StreamProvider.autoDispose<double>((ref) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return const Stream.empty();
  }
  return const EventChannel('linsy/media_volume').receiveBroadcastStream().map(
    (value) => (value as num).toDouble().clamp(0.0, 1.0),
  );
});

/// Native mobile playback uses the device's media volume, not a second gain.
bool get usesSystemMediaVolume =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);
