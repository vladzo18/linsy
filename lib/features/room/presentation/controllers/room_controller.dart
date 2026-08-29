import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:linsy/features/auth/domain/models/app_user.dart';
import 'package:linsy/features/home/presentation/controllers/home_controller.dart';
import 'package:linsy/features/room/application/room_membership_service.dart';

import '../../../../app/session/app_session_controller.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/providers/room_repository_provider.dart';
import '../../domain/models/room_member.dart';
import '../../application/sync/room_consistency_coordinator_provider.dart';
import '../../application/sync/room_snapshot_sync.dart';
import '../../../profile/application/profile_store.dart';
import 'room_state.dart';

final roomControllerProvider = NotifierProvider.autoDispose
    .family<RoomController, RoomState, String>(RoomController.new);

class RoomController extends Notifier<RoomState> {
  RoomController(this.roomId);

  final String roomId;

  StreamSubscription<List<RoomMember>>? _membersSubscription;

  @override
  RoomState build() {
    final repository = ref.read(roomRepositoryProvider);

    final consistencyCoordinator = ref.watch(
      roomConsistencyCoordinatorProvider(roomId),
    );

    final membersSync = RoomSnapshotSync<List<RoomMember>>(
      read: () {
        if (state.status != RoomStatus.ready) {
          return null;
        }

        return state.members;
      },

      load: () => repository.getRoomMembers(roomId),

      write: (members) {
        final uniqueMembers = <String, RoomMember>{};

        for (final member in members) {
          uniqueMembers[member.userId] = member;
        }

        state = RoomState.ready(uniqueMembers.values.toList());
      },
    );

    final unregisterSync = consistencyCoordinator.register(membersSync);

    // ===============================================================
    // ROOM MEMBERS
    // ===============================================================
    //
    // Старый рабочий realtime:
    // join / leave / role changes.
    // ===============================================================

    _membersSubscription = repository.watchRoomMembers(roomId).listen((
      members,
    ) {
      final uniqueMembers = <String, RoomMember>{};

      for (final member in members) {
        uniqueMembers[member.userId] = member;
      }

      final result = uniqueMembers.values.toList();

      state = RoomState.ready(result);

      unawaited(
        ref
            .read(profileStoreProvider.notifier)
            .ensureProfiles(result.map((member) => member.userId)),
      );
    });

    // ===============================================================
    // CLEANUP
    // ===============================================================

    ref.onDispose(() {
      unregisterSync();
      membersSync.dispose();
      unawaited(_membersSubscription?.cancel());
      _membersSubscription = null;
    });

    return const RoomState.loading();
  }

  // ===================================================================
  // LEAVE ROOM
  // ===================================================================

  Future<void> leaveRoom() async {
    final authState = ref.read(authControllerProvider);

    final user = authState.user;

    if (user == null) {
      return;
    }

    state = RoomState.leaving(state.members);

    try {
      await ref
          .read(roomMembershipServiceProvider)
          .leaveRoom(roomId: roomId, userId: user.id);

      await ref.read(appSessionControllerProvider.notifier).refresh();

      ref.invalidate(homeControllerProvider);
    } catch (error) {
      state = const RoomState.error('Failed to leave the room.');
    }
  }
}
