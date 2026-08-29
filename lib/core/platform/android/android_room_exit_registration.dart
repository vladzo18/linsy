import 'package:flutter/services.dart';

import '../room_exit_registration.dart';

class AndroidRoomExitRegistration implements RoomExitRegistration {
  const AndroidRoomExitRegistration();

  static const _channel = MethodChannel('linsy/room_exit');

  @override
  Future<void> register({required String cleanupToken}) async {
    await _channel.invokeMethod<void>('register', {
      'cleanupToken': cleanupToken,
    });
  }

  @override
  Future<void> clear() async {
    await _channel.invokeMethod<void>('clear');
  }
}
