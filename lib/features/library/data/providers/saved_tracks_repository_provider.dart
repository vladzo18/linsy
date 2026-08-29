import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/repositories/saved_tracks_repository.dart';
import '../repositories/supabase_saved_tracks_repository.dart';

final savedTracksRepositoryProvider = Provider<SavedTracksRepository>((ref) {
  return SupabaseSavedTracksRepository(Supabase.instance.client);
});
