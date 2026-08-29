import '../../domain/models/room_member.dart';

enum RoomStatus { loading, ready, leaving, error }

class RoomState {
  final RoomStatus status;
  final List<RoomMember> members;
  final String? errorMessage;

  const RoomState({
    required this.status,
    this.members = const [],
    this.errorMessage,
  });

  const RoomState.loading()
    : status = RoomStatus.loading,
      members = const [],
      errorMessage = null;

  const RoomState.ready(this.members)
    : status = RoomStatus.ready,
      errorMessage = null;

  const RoomState.leaving(this.members)
    : status = RoomStatus.leaving,
      errorMessage = null;

  const RoomState.error(String message)
    : status = RoomStatus.error,
      members = const [],
      errorMessage = message;
}
