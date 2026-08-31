import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/repositories/room_playback_history_repository.dart';
import '../repositories/supabase_room_playback_history_repository.dart';

final roomPlaybackHistoryRepositoryProvider =
    Provider<RoomPlaybackHistoryRepository>((ref) {
      return SupabaseRoomPlaybackHistoryRepository(Supabase.instance.client);
    });
