import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'network_monitor.dart';
import 'network_recoverable.dart';
import 'network_recovery_coordinator.dart';
import 'network_state.dart';

final networkMonitorProvider = Provider<NetworkMonitor>((ref) {
  final monitor = NetworkMonitor(
    connectivity: Connectivity(),
    supabase: Supabase.instance.client,
  );

  ref.onDispose(() {
    unawaited(monitor.dispose());
  });

  return monitor;
});

final networkStateProvider = StreamProvider<NetworkState>((ref) async* {
  final monitor = ref.watch(networkMonitorProvider);

  // StreamController не replay-ит последнее значение,
  // поэтому сначала отдаём current state вручную.
  yield monitor.state;

  yield* monitor.states;
});

final networkRecoveryCoordinatorProvider = Provider<NetworkRecoveryCoordinator>(
  (ref) {
    final coordinator = NetworkRecoveryCoordinator(
      ref.watch(networkMonitorProvider),
    );

    ref.onDispose(() {
      unawaited(coordinator.dispose());
    });

    return coordinator;
  },
);

final networkRecoveryEventsProvider = StreamProvider<NetworkRecoveryContext>((
  ref,
) {
  final coordinator = ref.watch(networkRecoveryCoordinatorProvider);

  return coordinator.recoveryEvents;
});
