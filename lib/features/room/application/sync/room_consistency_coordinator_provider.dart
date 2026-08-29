import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/lifecycle/app_lifecycle_provider.dart';
import '../../../../core/network/network_monitor_provider.dart';
import 'room_consistency_coordinator.dart';

final roomConsistencyCoordinatorProvider = Provider.autoDispose
    .family<RoomConsistencyCoordinator, String>((ref, roomId) {
      final coordinator = RoomConsistencyCoordinator(
        roomId: roomId,
        lifecycleService: ref.watch(appLifecycleServiceProvider),
        networkMonitor: ref.watch(networkMonitorProvider),
        recoveryCoordinator: ref.watch(networkRecoveryCoordinatorProvider),
      );

      coordinator.start();

      ref.onDispose(() {
        unawaited(coordinator.dispose());
      });

      return coordinator;
    });
