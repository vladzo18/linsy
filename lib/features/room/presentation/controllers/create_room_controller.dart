import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/room.dart';
import 'create_room_state.dart';

final createRoomControllerProvider = NotifierProvider<CreateRoomController, CreateRoomState>( CreateRoomController.new );

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
        errorMessage: 'Enter a room name',
      );

      return null;
    }

    if (state.status == CreateRoomStatus.loading) {
      return null;
    }

    state = state.copyWith(
      status: CreateRoomStatus.loading,
      clearErrorMessage: true,
    );

    try {
      // Временная имитация запроса к серверу.
      await Future.delayed(const Duration(milliseconds: 700));

      final room = Room(
        id: 'ABC123',
        name: name,
        hostId: 'local-user',
      );
      
      state = state.copyWith(
        status: CreateRoomStatus.idle,
      );

      return room;
    } catch (error) {
      state = state.copyWith(
        status: CreateRoomStatus.error,
        errorMessage: 'Failed to create room',
      );
      return null;
    }
  }
}