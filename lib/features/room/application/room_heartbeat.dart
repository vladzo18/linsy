import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/session/app_session_controller.dart';
import '../../../core/lifecycle/app_lifecycle_provider.dart';
import 'room_exit_token_service.dart';

/// One in-flight renewal; stopping prevents late responses from touching UI.
class RoomHeartbeat {
  RoomHeartbeat({required this.renew, required this.onExpired});
  final Future<bool?> Function() renew;
  final Future<void> Function() onExpired;
  Timer? _timer;
  bool _busy = false;
  bool _stopped = false;

  void start() {
    if (_stopped || _timer != null) return;
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(pulse()),
    );
    unawaited(pulse());
  }

  Future<void> pulse() async {
    if (_stopped || _busy) return;
    _busy = true;
    try {
      final active = await renew();
      if (!_stopped && active == false) {
        stop();
        await onExpired();
      }
    } catch (_) {
      // Network/deployment errors are not proof of an expired membership.
      debugPrint('[RoomHeartbeat] Renewal unavailable; will retry.');
    } finally {
      _busy = false;
    }
  }

  void stop() {
    _stopped = true;
    _timer?.cancel();
  }
}

final roomHeartbeatProvider = Provider.autoDispose.family<void, String>((
  ref,
  roomId,
) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  final tokens = ref.read(roomExitTokenServiceProvider);
  final heartbeat = RoomHeartbeat(
    renew: () => tokens.renew(roomId: roomId),
    onExpired: () => ref.read(appSessionControllerProvider.notifier).refresh(),
  );
  // A paused Activity can still be visible in PiP: do not stop on lifecycle pause.
  final lifecycle = ref.read(appLifecycleServiceProvider);
  final subscription = lifecycle.states.listen((_) {
    if (lifecycle.isForeground) unawaited(heartbeat.pulse());
  });
  heartbeat.start();
  ref.onDispose(() {
    heartbeat.stop();
    unawaited(subscription.cancel());
  });
});
