enum CreateRoomStatus { idle, loading, success, error }

class CreateRoomState {
  final String name;
  final CreateRoomStatus status;
  final String? errorMessage;

  const CreateRoomState({
    this.name = '',
    this.status = CreateRoomStatus.idle,
    this.errorMessage,
  });

  bool get canCreate => name.isNotEmpty && status != CreateRoomStatus.loading;

  CreateRoomState copyWith({
    String? name,
    CreateRoomStatus? status,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return CreateRoomState(
      name: name ?? this.name,
      status: status ?? this.status,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
    );
  }
}
