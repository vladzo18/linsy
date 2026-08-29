import 'dart:async';

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

final profileByIdProvider = Provider.family<UserProfile?, String>((
  ref,
  userId,
) {
  return ref.watch(profileStoreProvider.select((profiles) => profiles[userId]));
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

    final missing = ids.where(
      (id) => !state.containsKey(id) && !_loadingIds.contains(id),
    );

    final idsToLoad = missing.toList();

    if (idsToLoad.isEmpty) {
      return;
    }

    _loadingIds.addAll(idsToLoad);

    try {
      final profiles = await _repository.getProfiles(idsToLoad);

      _putProfiles(profiles);
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
  // LOCAL CACHE
  // ===================================================

  void _putProfile(UserProfile profile) {
    final current = state[profile.id];

    if (current == profile) {
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
      if (next[profile.id] != profile) {
        next[profile.id] = profile;
        changed = true;
      }
    }

    if (!changed) {
      return;
    }

    state = next;
  }
}
