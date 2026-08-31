import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/repositories/track_search_suggestions_repository.dart';
import '../repositories/supabase_track_search_suggestions_repository.dart';

final trackSearchSuggestionsRepositoryProvider =
    Provider<TrackSearchSuggestionsRepository>((ref) {
      return SupabaseTrackSearchSuggestionsRepository(Supabase.instance.client);
    });
