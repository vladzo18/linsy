import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:linsy/features/room/application/room_exit_token_service.dart';

import '../../../core/platform/room_exit_registration.dart';
import '../../../core/platform/room_exit_registration_provider.dart';
import '../data/local/recent_rooms_storage.dart';
import '../data/providers/room_repository_provider.dart';
import '../data/repositories/room_repository.dart';
import '../domain/models/room.dart';

final roomMembershipServiceProvider = Provider<RoomMembershipService>((ref) {
  return RoomMembershipService(
    repository: ref.read(roomRepositoryProvider),
    recentRoomsStorage: ref.read(recentRoomsStorageProvider),
    exitRegistration: ref.read(roomExitRegistrationProvider),
    roomExitTokenService: ref.read(roomExitTokenServiceProvider),
  );
});

class RoomMembershipService {
  RoomMembershipService({
    required this._repository,
    required this._recentRoomsStorage,
    required this._exitRegistration,
    required this._roomExitTokenService,
  });

  final RoomExitTokenService _roomExitTokenService;

  final RoomRepository _repository;

  final RecentRoomsStorage _recentRoomsStorage;

  final RoomExitRegistration _exitRegistration;

  // ===================================================================
  // CREATE
  // ===================================================================

  Future<Room> createRoom({
    required String name,
    required String hostId,
  }) async {
    final room = await _repository.createRoom(name: name, hostId: hostId);

    await _afterEnter(roomId: room.id, userId: hostId);

    return room;
  }

  // ===================================================================
  // JOIN
  // ===================================================================

  Future<void> joinRoom({
    required String roomId,
    required String userId,
  }) async {
    await _repository.joinRoom(roomId: roomId, userId: userId);

    await _afterEnter(roomId: roomId, userId: userId);
  }

  // ===================================================================
  // RESTORE
  // ===================================================================

  Future<void> restoreRegistration({
    required String roomId,
    required String userId,
  }) async {
    try {
      final cleanupToken = await _roomExitTokenService.issue(roomId: roomId);

      await _exitRegistration.register(cleanupToken: cleanupToken);
    } catch (_) {
      // Best effort.
    }
  }

  // ===================================================================
  // LEAVE
  // ===================================================================

  Future<void> leaveRoom({
    required String roomId,
    required String userId,
  }) async {
    await _repository.leaveRoom(roomId: roomId, userId: userId);

    try {
      await _exitRegistration.clear();
    } catch (_) {}
  }

  // ===================================================================
  // AFTER ENTER
  // ===================================================================

  Future<void> _afterEnter({
    required String roomId,
    required String userId,
  }) async {
    // ===============================================================
    // ANDROID CLEANUP TOKEN
    // ===============================================================

    try {
      final cleanupToken = await _roomExitTokenService.issue(roomId: roomId);

      await _exitRegistration.register(cleanupToken: cleanupToken);
    } catch (_) {
      // Native exit cleanup is optional.
    }

    // ===============================================================
    // RECENT
    // ===============================================================

    try {
      await _recentRoomsStorage.remember(userId: userId, roomId: roomId);
    } catch (_) {}
  }
}
