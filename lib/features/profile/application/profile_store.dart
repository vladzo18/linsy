import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/lifecycle/app_lifecycle_provider.dart';
import '../../../core/network/network_monitor_provider.dart';
import '../data/providers/profile_repository_provider.dart';
import '../domain/models/user_profile.dart';
import '../domain/repositories/profile_repository.dart';
import 'profile_sync_coordinator.dart';

final profileStoreProvider =
    NotifierProvider<ProfileStoreController, Map<String, UserProfile>>(
      ProfileStoreController.new,
    );

final profileByIdProvider = Provider.autoDispose.family<UserProfile?, String>((
  ref,
  userId,
) {
  final profile = ref.watch(
    profileStoreProvider.select((profiles) => profiles[userId]),
  );

  if (profile == null && userId.isNotEmpty) {
    final store = ref.read(profileStoreProvider.notifier);

    unawaited(Future<void>.microtask(() => store.ensureProfiles([userId])));
  }

  return profile;
});

class ProfileStoreController extends Notifier<Map<String, UserProfile>> {
  late ProfileRepository _repository;

  ProfileSyncCoordinator? _syncCoordinator;

  final Set<String> _trackedIds = {};

  final Set<String> _loadingIds = {};

  @override
  Map<String, UserProfile> build() {
    _repository = ref.read(profileRepositoryProvider);

    final coordinator = ProfileSyncCoordinator(
      repository: _repository,
      lifecycleService: ref.read(appLifecycleServiceProvider),
      networkMonitor: ref.read(networkMonitorProvider),
      recoveryCoordinator: ref.read(networkRecoveryCoordinatorProvider),
      readTrackedIds: () => Set<String>.unmodifiable(_trackedIds),
      writeProfile: _putProfile,
      writeProfiles: _putProfiles,
    );

    _syncCoordinator = coordinator;

    coordinator.start();

    ref.onDispose(() {
      final current = _syncCoordinator;

      _syncCoordinator = null;

      if (current != null) {
        unawaited(current.dispose());
      }

      _trackedIds.clear();
      _loadingIds.clear();
    });

    return const {};
  }

  // ===================================================
  // ENSURE
  // ===================================================

  Future<void> ensureProfiles(Iterable<String> userIds) async {
    final ids = userIds.where((id) => id.isNotEmpty).toSet();

    if (ids.isEmpty) {
      return;
    }

    _trackedIds.addAll(ids);

    final idsToLoad = ids
        .where((id) => !state.containsKey(id) && !_loadingIds.contains(id))
        .toList();

    if (idsToLoad.isEmpty) {
      return;
    }

    _loadingIds.addAll(idsToLoad);

    try {
      final profiles = await _repository.getProfiles(idsToLoad);

      _putProfiles(profiles);
    } catch (error, stackTrace) {
      developer.log(
        'Failed to load profiles',
        name: 'linsy.profile',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _loadingIds.removeAll(idsToLoad);
    }
  }

  // ===================================================
  // FORCE REFRESH
  // ===================================================

  Future<void> refreshProfiles(Iterable<String> userIds) async {
    final ids = userIds.where((id) => id.isNotEmpty).toSet();

    if (ids.isEmpty) {
      return;
    }

    _trackedIds.addAll(ids);

    final profiles = await _repository.getProfiles(ids);

    _putProfiles(profiles);
  }

  // ===================================================
  // UPDATE
  // ===================================================

  Future<UserProfile> updateProfile({
    required String userId,
    required String displayName,
    Uint8List? avatarBytes,
    String? avatarContentType,
  }) async {
    _trackedIds.add(userId);

    final profile = await _repository.updateProfile(
      userId: userId,
      displayName: displayName,
      avatarBytes: avatarBytes,
      avatarContentType: avatarContentType,
    );

    // Не ждём Realtime.
    //
    // UPDATE вернул authoritative DB row,
    // поэтому обновляем cache сразу.
    _putProfile(profile);

    return profile;
  }

  // ===================================================
  // LOCAL CACHE
  // ===================================================

  void _putProfile(UserProfile profile) {
    final current = state[profile.id];

    if (!_shouldApply(current, profile)) {
      return;
    }

    state = {...state, profile.id: profile};
  }

  void _putProfiles(List<UserProfile> profiles) {
    if (profiles.isEmpty) {
      return;
    }

    final next = Map<String, UserProfile>.from(state);

    var changed = false;

    for (final profile in profiles) {
      final current = next[profile.id];

      if (!_shouldApply(current, profile)) {
        continue;
      }

      next[profile.id] = profile;

      changed = true;
    }

    if (!changed) {
      return;
    }

    state = next;
  }

  // ===================================================
  // STALE GUARD
  // ===================================================

  bool _shouldApply(UserProfile? current, UserProfile incoming) {
    if (current == null) {
      return true;
    }

    if (current == incoming) {
      return false;
    }

    final currentUpdatedAt = current.updatedAt;

    final incomingUpdatedAt = incoming.updatedAt;

    if (currentUpdatedAt != null &&
        incomingUpdatedAt != null &&
        incomingUpdatedAt.isBefore(currentUpdatedAt)) {
      return false;
    }

    return true;
  }
}
