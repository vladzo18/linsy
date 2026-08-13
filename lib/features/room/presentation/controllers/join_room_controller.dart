import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'join_room_state.dart';

final joinRoomControllerProvider = NotifierProvider<JoinRoomController, JoinRoomState>(
  JoinRoomController.new,
);

class JoinRoomController extends Notifier<JoinRoomState> {
  @override
  JoinRoomState build() {
    return const JoinRoomState();
  }

  void setRoomId(String roomId) {
    state = state.copyWith(
      roomId: roomId, 
      status: JoinRoomStatus.idle,
      clearErrorMessage: true);
  }

  Future<String?> joinRoom() async {
    final roomId = state.roomId.trim().toUpperCase();

    if (roomId.isEmpty) {
      state = state.copyWith(
        status: JoinRoomStatus.error,
        errorMessage: 'Enter a room ID',
      );

      return null;
    }

    if (state.status == JoinRoomStatus.loading) {
      return null;
    }

    state = state.copyWith(
      roomId: roomId,
      status: JoinRoomStatus.loading,
      clearErrorMessage: true,
    );

    try {
      // Simulate a network request to join the room
      await Future.delayed(const Duration(milliseconds: 500));

      if (roomId != 'ABC123') {
        state = state.copyWith(
          status: JoinRoomStatus.error,
          errorMessage: 'Room not found',
        );

        return null;
      }

      state = state.copyWith(
        status: JoinRoomStatus.idle,
      );

      return roomId;
      
    } catch (error) {
      state = state.copyWith(
        status: JoinRoomStatus.error,
        errorMessage: 'No able to join the room',
      );

      return null;
    }

  }
}