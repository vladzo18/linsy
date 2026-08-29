import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:linsy/features/room/application/room_membership_service.dart';

import '../../../../app/session/app_session_controller.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/providers/room_repository_provider.dart';
import '../../domain/models/room.dart';
import 'create_room_state.dart';

final createRoomControllerProvider =
    NotifierProvider<CreateRoomController, CreateRoomState>(
      CreateRoomController.new,
    );

class CreateRoomController extends Notifier<CreateRoomState> {
  @override
  CreateRoomState build() {
    return const CreateRoomState();
  }

  void setName(String name) {
    state = state.copyWith(
      name: name,
      status: CreateRoomStatus.idle,
      clearErrorMessage: true,
    );
  }

  Future<Room?> createRoom() async {
    final name = state.name.trim();

    if (name.isEmpty) {
      state = state.copyWith(
        status: CreateRoomStatus.error,
        errorMessage: 'Enter a room name.',
      );

      return null;
    }

    if (state.status == CreateRoomStatus.loading) {
      return null;
    }

    final authState = ref.read(authControllerProvider);
    final user = authState.user;

    if (user == null) {
      state = state.copyWith(
        status: CreateRoomStatus.error,
        errorMessage: 'You must be signed in to create a room.',
      );

      return null;
    }

    state = state.copyWith(
      status: CreateRoomStatus.loading,
      clearErrorMessage: true,
    );

    try {
      final room = await ref
          .read(roomMembershipServiceProvider)
          .createRoom(name: name, hostId: user.id);

      ref.read(appSessionControllerProvider.notifier).enterRoom(room.id);

      state = state.copyWith(status: CreateRoomStatus.idle);

      return room;
    } catch (error) {
      state = state.copyWith(
        status: CreateRoomStatus.error,
        errorMessage: 'Failed to create the room.',
      );

      return null;
    }
  }
}
