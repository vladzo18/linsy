import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui' show AppLifecycleState;

import '../../../../core/lifecycle/app_lifecycle_service.dart';
import '../../../../core/network/network_monitor.dart';
import '../../../../core/network/network_recoverable.dart';
import '../../../../core/network/network_recovery_coordinator.dart';
import 'room_consistency_target.dart';

class RoomConsistencyCoordinator implements NetworkRecoverable {
  RoomConsistencyCoordinator({
    required this.roomId,
    required this._lifecycleService,
    required this._networkMonitor,
    required this._recoveryCoordinator,
  });

  final String roomId;

  final AppLifecycleService _lifecycleService;
  final NetworkMonitor _networkMonitor;
  final NetworkRecoveryCoordinator _recoveryCoordinator;

  final Set<RoomConsistencyTarget> _targets = {};

  StreamSubscription<AppLifecycleState>? _lifecycleSubscription;

  Timer? _timer;

  void Function()? _unregisterRecovery;

  bool _started = false;
  bool _disposed = false;
  bool _syncing = false;

  bool _pendingForcedSync = false;

  DateTime? _lastSuccessfulSyncAt;

  static const Duration _interval = Duration(seconds: 45);

  static const Duration _periodicMinimumGap = Duration(seconds: 30);

  static const Duration _foregroundMinimumGap = Duration(seconds: 5);

  // ===================================================
  // START
  // ===================================================

  void start() {
    if (_started || _disposed) {
      return;
    }

    _started = true;

    _unregisterRecovery = _recoveryCoordinator.register(this);

    _timer = Timer.periodic(_interval, (_) {
      unawaited(_runSync(minimumGap: _periodicMinimumGap));
    });

    _lifecycleSubscription = _lifecycleService.states.listen((state) {
      if (state != AppLifecycleState.resumed) {
        return;
      }

      unawaited(_runSync(minimumGap: _foregroundMinimumGap));
    });
  }

  // ===================================================
  // TARGETS
  // ===================================================

  void Function() register(RoomConsistencyTarget target) {
    if (_disposed) {
      throw StateError('RoomConsistencyCoordinator is disposed.');
    }

    _targets.add(target);

    var registered = true;

    return () {
      if (!registered) {
        return;
      }

      registered = false;

      _targets.remove(target);
    };
  }

  // ===================================================
  // NETWORK RECOVERY
  // ===================================================

  @override
  Future<void> recoverNetwork(NetworkRecoveryContext context) {
    return _runSync(force: true);
  }

  // ===================================================
  // SYNC
  // ===================================================

  Future<void> _runSync({
    bool force = false,
    Duration minimumGap = Duration.zero,
  }) async {
    if (_disposed) {
      return;
    }

    if (!_lifecycleService.isForeground) {
      return;
    }

    if (!_networkMonitor.state.isOnline) {
      return;
    }

    if (_syncing) {
      if (force) {
        _pendingForcedSync = true;
      }

      return;
    }

    final now = DateTime.now().toUtc();

    final lastSync = _lastSuccessfulSyncAt;

    if (!force && lastSync != null && now.difference(lastSync) < minimumGap) {
      return;
    }

    _syncing = true;

    try {
      final targets = List<RoomConsistencyTarget>.from(_targets);

      await Future.wait(targets.map(_syncSafely));

      _lastSuccessfulSyncAt = DateTime.now().toUtc();
    } finally {
      _syncing = false;

      if (_pendingForcedSync && !_disposed) {
        _pendingForcedSync = false;

        unawaited(_runSync(force: true));
      }
    }
  }

  Future<void> _syncSafely(RoomConsistencyTarget target) async {
    try {
      await target.resync();
    } catch (error, stackTrace) {
      developer.log(
        'Consistency sync failed for '
        '${target.runtimeType}',
        name: 'linsy.room.sync',
        error: error,
        stackTrace: stackTrace,
      );
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

    _timer?.cancel();
    _timer = null;

    _unregisterRecovery?.call();
    _unregisterRecovery = null;

    await _lifecycleSubscription?.cancel();
    _lifecycleSubscription = null;

    _targets.clear();
  }
}
