import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:linsy/features/room/domain/repositories/supabase_playback_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/repositories/playback_repository.dart';

final playbackRepositoryProvider = Provider<PlaybackRepository>((ref) {
  return SupabasePlaybackRepository(Supabase.instance.client);
});
