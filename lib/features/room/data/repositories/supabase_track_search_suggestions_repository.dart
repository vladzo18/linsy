import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/repositories/track_search_suggestions_repository.dart';

class SupabaseTrackSearchSuggestionsRepository
    implements TrackSearchSuggestionsRepository {
  SupabaseTrackSearchSuggestionsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<String>> suggest(String query) async {
    final cleanQuery = query.trim();

    if (cleanQuery.length < 2) {
      return const [];
    }

    final response = await _client.functions.invoke(
      'youtube-suggestions',
      body: {'query': cleanQuery},
    );

    final data = response.data;

    if (data is! Map) {
      throw StateError(
        'Invalid response from '
        'youtube-suggestions.',
      );
    }

    final rawSuggestions = data['suggestions'];

    if (rawSuggestions is! List) {
      return const [];
    }

    return rawSuggestions
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .take(8)
        .toList(growable: false);
  }
}
