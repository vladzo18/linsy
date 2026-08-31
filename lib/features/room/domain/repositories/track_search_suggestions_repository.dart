abstract interface class TrackSearchSuggestionsRepository {
  Future<List<String>> suggest(String query);
}
