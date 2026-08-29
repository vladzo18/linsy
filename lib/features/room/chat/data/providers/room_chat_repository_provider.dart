import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/repositories/room_chat_repository.dart';
import '../repositories/supabase_room_chat_repository.dart';

final roomChatRepositoryProvider = Provider<RoomChatRepository>((ref) {
  return SupabaseRoomChatRepository(Supabase.instance.client);
});
