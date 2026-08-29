import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/track_search_repository_provider.dart';
import '../../domain/models/track_search_result.dart';

final trackSearchControllerProvider =
    NotifierProvider<
      TrackSearchController,
      AsyncValue<List<TrackSearchResult>>
    >(TrackSearchController.new);

class TrackSearchController
    extends Notifier<AsyncValue<List<TrackSearchResult>>> {
  @override
  AsyncValue<List<TrackSearchResult>> build() {
    return const AsyncData([]);
  }

  Future<void> search(String query) async {
    final cleanQuery = query.trim();

    if (cleanQuery.length < 2) {
      state = const AsyncData([]);
      return;
    }

    state = const AsyncLoading();

    try {
      final results = await ref
          .read(trackSearchRepositoryProvider)
          .search(cleanQuery);

      state = AsyncData(results);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  void clear() {
    state = const AsyncData([]);
  }
}
