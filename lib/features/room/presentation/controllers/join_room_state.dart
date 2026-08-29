enum JoinRoomStatus {
  idle,
  loading,
  error,
}

class JoinRoomState {
  final String roomId;
  final JoinRoomStatus status;
  final String? errorMessage;

  const JoinRoomState({
    this.roomId = '',
    this.status = JoinRoomStatus.idle,
    this.errorMessage,
  });

  bool get canJoin =>
      roomId.trim().isNotEmpty &&
      status != JoinRoomStatus.loading;

  JoinRoomState copyWith({
    String? roomId,
    JoinRoomStatus? status,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return JoinRoomState(
      roomId: roomId ?? this.roomId,
      status: status ?? this.status,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
    );
  }
}