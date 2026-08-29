import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../room/data/local/recent_rooms_storage.dart';
import '../../../room/data/providers/room_repository_provider.dart';
import 'home_state.dart';

final homeControllerProvider = AsyncNotifierProvider<HomeController, HomeState>(
  HomeController.new,
);

class HomeController extends AsyncNotifier<HomeState> {
  @override
  Future<HomeState> build() async {
    final authState = ref.watch(authControllerProvider);

    return _load(authState.user?.id);
  }

  Future<HomeState> _load(String? userId) async {
    if (userId == null) {
      return const HomeState.ready([]);
    }

    final repository = ref.read(roomRepositoryProvider);

    // ===============================================================
    // OWNED ROOMS
    // ===============================================================

    try {
      final ownedRooms = await repository.getMyRooms(userId);

      final items = <HomeRoomItem>[
        for (final room in ownedRooms)
          HomeRoomItem(room: room, type: HomeRoomType.owned),
      ];

      final ownedIds = ownedRooms.map((room) => room.id).toSet();

      // =============================================================
      // RECENT ROOMS
      //
      // Failure of local history must not prevent
      // owned rooms from loading.
      // =============================================================

      try {
        final storage = ref.read(recentRoomsStorageProvider);

        final history = await storage.load(userId);

        // Own rooms are displayed separately at the
        // beginning of the unified Rooms list.
        final recentHistory = history
            .where((entry) => !ownedIds.contains(entry.roomId))
            .toList();

        if (recentHistory.isEmpty) {
          // Removes obsolete history entries that
          // now correspond only to owned rooms.
          await storage.keepOnly(userId: userId, roomIds: const <String>{});

          return HomeState.ready(items);
        }

        final recentIds = recentHistory.map((entry) => entry.roomId).toList();

        final existingRooms = await repository.getRoomsByIds(recentIds);

        final roomsById = {for (final room in existingRooms) room.id: room};

        // Only IDs returned by Supabase still exist.
        final existingIds = roomsById.keys.toSet();

        // Remove locally stored rooms that no
        // longer exist.
        await storage.keepOnly(userId: userId, roomIds: existingIds);

        // Keep the local last-visited order instead
        // of the arbitrary DB result order.
        for (final entry in recentHistory) {
          final room = roomsById[entry.roomId];

          if (room == null) {
            continue;
          }

          items.add(
            HomeRoomItem(
              room: room,
              type: HomeRoomType.recent,
              lastVisitedAt: entry.lastVisitedAt,
            ),
          );
        }
      } catch (_) {
        // Recent rooms are optional.
        //
        // If local storage or recent-room fetching
        // fails, Home still shows owned rooms.
      }

      return HomeState.ready(items);
    } catch (_) {
      return const HomeState.error('Failed to load your rooms.');
    }
  }

  Future<void> refresh() async {
    final authState = ref.read(authControllerProvider);

    state = const AsyncLoading();

    state = await AsyncValue.guard(() => _load(authState.user?.id));
  }
}
