import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/controllers/auth_controller.dart';
import '../data/providers/saved_tracks_repository_provider.dart';
import '../domain/models/saved_track.dart';

final savedTracksControllerProvider =
    AsyncNotifierProvider<SavedTracksController, List<SavedTrack>>(
      SavedTracksController.new,
    );

class SavedTracksController extends AsyncNotifier<List<SavedTrack>> {
  // ===================================================
  // BUILD
  // ===================================================

  @override
  Future<List<SavedTrack>> build() async {
    final user = ref.watch(authControllerProvider).user;

    if (user == null) {
      return const [];
    }

    final repository = ref.read(savedTracksRepositoryProvider);

    return repository.getSavedTracks(user.id);
  }

  // ===================================================
  // CHECK
  // ===================================================

  bool isSaved({required String source, required String trackId}) {
    final tracks = state.value ?? const <SavedTrack>[];

    return tracks.any(
      (track) => track.source == source && track.trackId == trackId,
    );
  }

  // ===================================================
  // SAVE
  // ===================================================

  Future<void> saveTrack({
    required String source,
    required String trackId,
    required String title,
    required String channelTitle,
    String? thumbnailUrl,
    int? durationMs,
  }) async {
    final user = ref.read(authControllerProvider).user;

    if (user == null) {
      throw StateError('Cannot save a track while signed out.');
    }

    final current = state.value ?? const <SavedTrack>[];

    final alreadySaved = current.any(
      (track) => track.source == source && track.trackId == trackId,
    );

    if (alreadySaved) {
      return;
    }

    final repository = ref.read(savedTracksRepositoryProvider);

    final saved = await repository.saveTrack(
      userId: user.id,
      source: source,
      trackId: trackId,
      title: title,
      channelTitle: channelTitle,
      thumbnailUrl: thumbnailUrl,
      durationMs: durationMs,
    );

    state = AsyncData([saved, ...current]);
  }

  // ===================================================
  // REMOVE
  // ===================================================

  Future<void> removeTrack({
    required String source,
    required String trackId,
  }) async {
    final user = ref.read(authControllerProvider).user;

    if (user == null) {
      throw StateError('Cannot remove a saved track while signed out.');
    }

    final repository = ref.read(savedTracksRepositoryProvider);

    await repository.removeTrack(
      userId: user.id,
      source: source,
      trackId: trackId,
    );

    final current = state.value ?? const <SavedTrack>[];

    state = AsyncData(
      current
          .where((track) => track.source != source || track.trackId != trackId)
          .toList(),
    );
  }

  // ===================================================
  // RELOAD
  // ===================================================

  Future<void> reload() async {
    final user = ref.read(authControllerProvider).user;

    if (user == null) {
      state = const AsyncData([]);
      return;
    }

    state = const AsyncLoading();

    state = await AsyncValue.guard(() {
      return ref.read(savedTracksRepositoryProvider).getSavedTracks(user.id);
    });
  }
}
