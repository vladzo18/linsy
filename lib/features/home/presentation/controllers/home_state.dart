import '../../../../features/room/domain/models/room.dart';

enum HomeStatus { loading, ready, error }

enum HomeRoomType { owned, recent }

class HomeRoomItem {
  const HomeRoomItem({
    required this.room,
    required this.type,
    this.lastVisitedAt,
  });

  final Room room;
  final HomeRoomType type;
  final DateTime? lastVisitedAt;

  bool get isOwned => type == HomeRoomType.owned;

  bool get isRecent => type == HomeRoomType.recent;
}

class HomeState {
  final HomeStatus status;
  final List<HomeRoomItem> rooms;
  final String? errorMessage;

  const HomeState({
    required this.status,
    this.rooms = const [],
    this.errorMessage,
  });

  const HomeState.loading()
    : status = HomeStatus.loading,
      rooms = const [],
      errorMessage = null;

  const HomeState.ready(this.rooms)
    : status = HomeStatus.ready,
      errorMessage = null;

  const HomeState.error(String message)
    : status = HomeStatus.error,
      rooms = const [],
      errorMessage = message;

  // Temporary compatibility with the
  // current HomePage.
  List<Room> get myRooms {
    return rooms
        .where((item) => item.isOwned)
        .map((item) => item.room)
        .toList();
  }
}
