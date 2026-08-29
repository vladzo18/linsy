import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:linsy/features/home/presentation/controllers/home_controller.dart';
import 'package:linsy/features/room/application/room_membership_service.dart';

import '../../../../app/session/app_session_controller.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/providers/room_repository_provider.dart';
import '../../domain/models/room_member.dart';
import 'room_state.dart';

final roomControllerProvider =
    NotifierProvider.family<RoomController, RoomState, String>(
      RoomController.new,
    );

class RoomController extends Notifier<RoomState> {
  RoomController(this.roomId);

  final String roomId;

  StreamSubscription<List<RoomMember>>? _membersSubscription;

  StreamSubscription? _profilesSubscription;

  @override
  RoomState build() {
    final repository = ref.read(roomRepositoryProvider);

    // ===============================================================
    // LOCAL PROFILE UPDATE
    // ===============================================================
    //
    // Когда текущий пользователь сохраняет свой профиль,
    // AuthController уже содержит новый AppUser.
    // Поэтому обновляем его сразу, даже не ожидая realtime.
    // ===============================================================

    ref.listen(authControllerProvider, (previous, next) {
      final user = next.user;

      if (user == null) {
        return;
      }

      if (state.status != RoomStatus.ready) {
        return;
      }

      final currentMembers = state.members;

      var found = false;

      final updatedMembers = currentMembers.map((member) {
        if (member.user.id != user.id) {
          return member;
        }

        found = true;

        return RoomMember(
          user: user,
          role: member.role,
          joinedAt: member.joinedAt,
        );
      }).toList();

      if (!found) {
        return;
      }

      state = RoomState.ready(updatedMembers);
    });

    // ===============================================================
    // ROOM MEMBERS
    // ===============================================================
    //
    // Старый рабочий realtime:
    // join / leave / role changes.
    // ===============================================================

    _membersSubscription = repository
        .watchRoomMembers(roomId)
        .listen(
          (members) {
            final uniqueMembers = <String, RoomMember>{};

            for (final member in members) {
              uniqueMembers[member.user.id] = member;
            }

            state = RoomState.ready(uniqueMembers.values.toList());
          },
          onError: (Object error, StackTrace stackTrace) {
            state = const RoomState.error('Failed to load room members.');
          },
        );

    // ===============================================================
    // PROFILE REALTIME
    // ===============================================================
    //
    // Слушаем UPDATE таблицы profiles.
    //
    // В realtime могут приходить профили пользователей,
    // которые вообще не находятся в этой комнате.
    //
    // Поэтому сначала ищем userId среди текущих участников.
    // ===============================================================

    _profilesSubscription = repository.watchProfileChanges().listen((profile) {
      if (state.status != RoomStatus.ready) {
        return;
      }

      final currentMembers = state.members;

      final index = currentMembers.indexWhere(
        (member) => member.user.id == profile.id,
      );

      // Пользователь не находится в этой комнате.
      if (index == -1) {
        return;
      }

      final oldMember = currentMembers[index];

      final updatedMember = RoomMember(
        user: profile,
        role: oldMember.role,
        joinedAt: oldMember.joinedAt,
      );

      final updatedMembers = List<RoomMember>.from(currentMembers);

      updatedMembers[index] = updatedMember;

      state = RoomState.ready(updatedMembers);
    });

    // ===============================================================
    // CLEANUP
    // ===============================================================

    ref.onDispose(() {
      _membersSubscription?.cancel();
      _profilesSubscription?.cancel();
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
