import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/room/application/room_membership_service.dart';
import '../features/room/data/providers/room_repository_provider.dart';

class AppExitService {
  AppExitService(this._container);

  final ProviderContainer _container;

  bool _cleanupStarted = false;

  Future<void> leaveCurrentRoom() async {
    if (_cleanupStarted) {
      return;
    }

    _cleanupStarted = true;

    try {
      await _leaveCurrentRoom().timeout(const Duration(seconds: 3));
    } catch (error, stackTrace) {
      debugPrint('[AppExit] Failed to leave room: $error');

      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _leaveCurrentRoom() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      return;
    }

    final repository = _container.read(roomRepositoryProvider);

    final room = await repository.getCurrentUserRoom(user.id);

    if (room == null) {
      return;
    }

    await _container
        .read(roomMembershipServiceProvider)
        .leaveRoom(roomId: room.id, userId: user.id);

    debugPrint('[AppExit] Left room ${room.id}.');
  }
}
