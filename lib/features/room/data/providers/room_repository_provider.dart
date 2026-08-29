import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:linsy/features/room/data/repositories/room_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/supabase_room_repository.dart';

final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  return SupabaseRoomRepository(Supabase.instance.client);
});
