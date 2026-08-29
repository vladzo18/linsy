import '../../../auth/domain/models/app_user.dart';

enum RoomMemberRole {
  host,
  moderator,
  member;

  static RoomMemberRole fromString(String value) {
    switch (value) {
      case 'host':
        return RoomMemberRole.host;

      case 'moderator':
        return RoomMemberRole.moderator;

      case 'member':
        return RoomMemberRole.member;

      default:
        throw ArgumentError('Unknown room member role: $value');
    }
  }
}

class RoomMember {
  final AppUser user;
  final RoomMemberRole role;
  final DateTime joinedAt;

  const RoomMember({
    required this.user,
    required this.role,
    required this.joinedAt,
  });

  bool get isHost => role == RoomMemberRole.host;

  bool get isModerator => role == RoomMemberRole.moderator;

  bool get canControlPlayback => isHost || isModerator;
}
