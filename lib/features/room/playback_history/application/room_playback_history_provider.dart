import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers/room_playback_history_repository_provider.dart';
import '../domain/models/room_playback_history_item.dart';

final roomPlaybackHistoryProvider = StreamProvider.autoDispose
    .family<List<RoomPlaybackHistoryItem>, String>((ref, roomId) {
      return ref
          .watch(roomPlaybackHistoryRepositoryProvider)
          .watchHistory(roomId);
    });
