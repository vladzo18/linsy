import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:linsy/features/room/domain/repositories/supabase_track_search_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/repositories/track_search_repository.dart';

final trackSearchRepositoryProvider =
    Provider<TrackSearchRepository>((ref) {
  return SupabaseTrackSearchRepository(
    Supabase.instance.client,
  );
});