import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'android/android_room_exit_registration.dart';
import 'noop_room_exit_registration.dart';
import 'room_exit_registration.dart';

final roomExitRegistrationProvider = Provider<RoomExitRegistration>((ref) {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return const AndroidRoomExitRegistration();
  }

  return const NoopRoomExitRegistration();
});
