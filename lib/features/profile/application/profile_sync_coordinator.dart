import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui' show AppLifecycleState;

import '../../../core/lifecycle/app_lifecycle_service.dart';
import '../../../core/network/network_monitor.dart';
import '../../../core/network/network_recoverable.dart';
import '../../../core/network/network_recovery_coordinator.dart';
import '../domain/models/user_profile.dart';
import '../domain/repositories/profile_repository.dart';

typedef TrackedProfileIdsReader = Set<String> Function();

typedef ProfileWriter = void Function(UserProfile profile);

typedef ProfilesWriter = void Function(List<UserProfile> profiles);

class ProfileSyncCoordinator implements NetworkRecoverable {
  ProfileSyncCoordinator({
    required this._repository,
    required this._lifecycleService,
    required this._networkMonitor,
    required this._recoveryCoordinator,
    required this._readTrackedIds,
    required this._writeProfile,
    required this._writeProfiles,
  });

  final ProfileRepository _repository;

  final AppLifecycleService _lifecycleService;

  final NetworkMonitor _networkMonitor;

  final NetworkRecoveryCoordinator _recoveryCoordinator;

  final TrackedProfileIdsReader _readTrackedIds;

  final ProfileWriter _writeProfile;

  final ProfilesWriter _writeProfiles;

  StreamSubscription<UserProfile>? _realtimeSubscription;

  StreamSubscription<AppLifecycleState>? _lifecycleSubscription;

  Timer? _consistencyTimer;

  void Function()? _unregisterRecovery;

  bool _started = false;
  bool _disposed = false;
  bool _syncing = false;

  static const Duration _consistencyInterval = Duration(seconds: 60);

  // ===================================================
  // START
  // ===================================================

  void start() {
    if (_started || _disposed) {
      return;
    }

    _started = true;

    _unregisterRecovery = _recoveryCoordinator.register(this);

    _realtimeSubscription = _repository.watchProfileChanges().listen(
      _handleRealtimeProfile,
      onError: (Object error, StackTrace stackTrace) {
        developer.log(
          'Profile realtime failed',
          name: 'linsy.profile',
          error: error,
          stackTrace: stackTrace,
        );
      },
    );

    _lifecycleSubscription = _lifecycleService.states.listen((state) {
      if (state != AppLifecycleState.resumed) {
        return;
      }

      unawaited(_resyncTrackedProfiles());
    });

    _consistencyTimer = Timer.periodic(_consistencyInterval, (_) {
      unawaited(_resyncTrackedProfiles());
    });
  }

  // ===================================================
  // REALTIME
  // ===================================================

  void _handleRealtimeProfile(UserProfile profile) {
    if (_disposed) {
      return;
    }

    final tracked = _readTrackedIds();

    // Не заполняем глобальный cache профилями,
    // которые приложение вообще сейчас
    // не использует.
    if (!tracked.contains(profile.id)) {
      return;
    }

    _writeProfile(profile);
  }

  // ===================================================
  // NETWORK RECOVERY
  // ===================================================

  @override
  Future<void> recoverNetwork(NetworkRecoveryContext context) {
    return _resyncTrackedProfiles();
  }

  // ===================================================
  // AUTHORITATIVE RESYNC
  // ===================================================

  Future<void> _resyncTrackedProfiles() async {
    if (_disposed || _syncing) {
      return;
    }

    if (!_lifecycleService.isForeground) {
      return;
    }

    if (!_networkMonitor.state.isOnline) {
      return;
    }

    final ids = _readTrackedIds();

    if (ids.isEmpty) {
      return;
    }

    _syncing = true;

    try {
      final profiles = await _repository.getProfiles(ids);

      if (_disposed) {
        return;
      }

      _writeProfiles(profiles);
    } catch (error, stackTrace) {
      developer.log(
        'Profile consistency sync failed',
        name: 'linsy.profile',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _syncing = false;
    }
  }

  // ===================================================
  // DISPOSE
  // ===================================================

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    _disposed = true;

    _consistencyTimer?.cancel();
    _consistencyTimer = null;

    _unregisterRecovery?.call();
    _unregisterRecovery = null;

    await _realtimeSubscription?.cancel();
    _realtimeSubscription = null;

    await _lifecycleSubscription?.cancel();
    _lifecycleSubscription = null;
  }
}
