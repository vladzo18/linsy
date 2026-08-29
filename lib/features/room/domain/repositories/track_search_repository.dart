import '../models/track_search_result.dart';

abstract interface class TrackSearchRepository {
  Future<List<TrackSearchResult>> search(String query);
}
