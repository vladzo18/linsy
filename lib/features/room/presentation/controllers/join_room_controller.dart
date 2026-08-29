import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:linsy/features/room/application/room_membership_service.dart';

import '../../../../app/session/app_session_controller.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/providers/room_repository_provider.dart';
import 'join_room_state.dart';

final joinRoomControllerProvider =
    NotifierProvider<JoinRoomController, JoinRoomState>(JoinRoomController.new);

class JoinRoomController extends Notifier<JoinRoomState> {
  @override
  JoinRoomState build() {
    return const JoinRoomState();
  }

  void setRoomId(String roomId) {
    state = state.copyWith(
      roomId: roomId.toUpperCase(),
      status: JoinRoomStatus.idle,
      clearErrorMessage: true,
    );
  }

  Future<String?> joinRoom() async {
    final roomCode = state.roomId.trim().toUpperCase();

    if (roomCode.isEmpty) {
      state = state.copyWith(
        status: JoinRoomStatus.error,
        errorMessage: 'Enter a room code.',
      );

      return null;
    }

    if (state.status == JoinRoomStatus.loading) {
      return null;
    }

    final authState = ref.read(authControllerProvider);

    final user = authState.user;

    if (user == null) {
      state = state.copyWith(
        status: JoinRoomStatus.error,
        errorMessage: 'You must be signed in to join a room.',
      );

      return null;
    }

    state = state.copyWith(
      status: JoinRoomStatus.loading,
      clearErrorMessage: true,
    );

    try {
      // -------------------------------------------------------------
      // ROOM LOOKUP
      // -------------------------------------------------------------

      final repository = ref.read(roomRepositoryProvider);

      final room = await repository.getRoomByCode(roomCode);

      if (room == null) {
        state = state.copyWith(
          status: JoinRoomStatus.error,
          errorMessage: 'Room not found.',
        );

        return null;
      }

      // -------------------------------------------------------------
      // JOIN
      //
      // Do not call repository.joinRoom directly.
      // MembershipService also handles:
      //
      // - recent room history
      // - Android exit registration
      // -------------------------------------------------------------

      await ref
          .read(roomMembershipServiceProvider)
          .joinRoom(roomId: room.id, userId: user.id);

      // -------------------------------------------------------------
      // SESSION
      // -------------------------------------------------------------

      ref.read(appSessionControllerProvider.notifier).enterRoom(room.id);

      state = state.copyWith(
        status: JoinRoomStatus.idle,
        clearErrorMessage: true,
      );

      return room.id;
    } catch (error) {
      state = state.copyWith(
        status: JoinRoomStatus.error,
        errorMessage: _mapJoinError(error),
      );

      return null;
    }
  }

  String _mapJoinError(Object error) {
    final message = error.toString().toLowerCase();

    if (message.contains('already in another room') ||
        message.contains('duplicate') ||
        message.contains('unique')) {
      return 'You are already in another room. Leave it first.';
    }

    if (message.contains('room not found')) {
      return 'Room not found.';
    }

    return 'Failed to join the room.';
  }
}
