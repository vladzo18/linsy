enum RoomAction {
  play,
  pause,
  seek,
  next,
  addTrack;

  String get value {
    switch (this) {
      case RoomAction.play:
        return 'play';
      case RoomAction.pause:
        return 'pause';
      case RoomAction.seek:
        return 'seek';
      case RoomAction.next:
        return 'next';
      case RoomAction.addTrack:
        return 'add_track';
    }
  }

  static RoomAction fromString(String value) {
    switch (value) {
      case 'play':
        return RoomAction.play;
      case 'pause':
        return RoomAction.pause;
      case 'seek':
        return RoomAction.seek;
      case 'next':
        return RoomAction.next;
      case 'add_track':
        return RoomAction.addTrack;
      default:
        throw ArgumentError('Unknown room action: $value');
    }
  }
}

enum RoomActionRequestStatus {
  pending,
  approved,
  rejected,
  cancelled;

  static RoomActionRequestStatus fromString(String value) {
    switch (value) {
      case 'pending':
        return RoomActionRequestStatus.pending;
      case 'approved':
        return RoomActionRequestStatus.approved;
      case 'rejected':
        return RoomActionRequestStatus.rejected;
      case 'cancelled':
        return RoomActionRequestStatus.cancelled;
      default:
        throw ArgumentError('Unknown request status: $value');
    }
  }
}

class RoomActionRequest {
  final String id;
  final String roomId;
  final String userId;
  final RoomAction action;
  final Map<String, dynamic>? payload;
  final RoomActionRequestStatus status;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? resolvedBy;

  const RoomActionRequest({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.action,
    required this.payload,
    required this.status,
    required this.createdAt,
    required this.resolvedAt,
    required this.resolvedBy,
  });
}
