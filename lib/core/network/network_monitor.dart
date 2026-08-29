import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'network_state.dart';

class NetworkMonitor {
  NetworkMonitor({
    required this._connectivity,
    required this._supabase,
  });

  final Connectivity _connectivity;
  final SupabaseClient _supabase;

  final StreamController<NetworkState> _stateController =
      StreamController<NetworkState>.broadcast(sync: true);

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  RealtimeChannel? _healthChannel;

  NetworkState _state = const NetworkState.initial();

  bool _started = false;
  bool _disposed = false;

  NetworkState get state => _state;

  Stream<NetworkState> get states => _stateController.stream;

  // ===================================================================
  // START
  // ===================================================================

  Future<void> start() async {
    if (_started || _disposed) {
      return;
    }

    _started = true;

    // Сначала начинаем слушать изменения,
    // чтобы не пропустить смену сети между checkConnectivity()
    // и созданием subscription.
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _handleConnectivityChanged,
      onError: (Object error, StackTrace stackTrace) {
        _emit(lastError: 'Connectivity error: $error');
      },
    );

    try {
      final initialConnectivity = await _connectivity.checkConnectivity();

      _handleConnectivityChanged(initialConnectivity);
    } catch (error) {
      _emit(
        initialized: true,
        transportAvailable: false,
        realtime: RealtimeConnectionStatus.disconnected,
        lastError: 'Initial connectivity check failed: $error',
      );
    }

    _startRealtimeHealthChannel();
  }

  // ===================================================================
  // CONNECTIVITY
  // ===================================================================

  void _handleConnectivityChanged(List<ConnectivityResult> results) {
    if (_disposed) {
      return;
    }

    final available = results.any(
      (result) => result != ConnectivityResult.none,
    );

    if (!available) {
      _emit(
        initialized: true,
        transportAvailable: false,
        realtime: RealtimeConnectionStatus.disconnected,
        clearError: true,
      );

      return;
    }

    // Network interface появился, но Realtime ещё должен
    // подтвердить, что WebSocket действительно восстановился.
    final nextRealtime = _state.realtime == RealtimeConnectionStatus.connected
        ? RealtimeConnectionStatus.connected
        : RealtimeConnectionStatus.reconnecting;

    _emit(
      initialized: true,
      transportAvailable: true,
      realtime: nextRealtime,
      clearError: true,
    );
  }

  // ===================================================================
  // SUPABASE REALTIME HEALTH
  // ===================================================================

  void _startRealtimeHealthChannel() {
    if (_disposed || _healthChannel != null) {
      return;
    }

    final channel = _supabase.channel('linsy:network-health');

    _healthChannel = channel;

    if (_state.transportAvailable) {
      _emit(realtime: RealtimeConnectionStatus.reconnecting);
    }

    channel.subscribe((status, error) {
      if (_disposed) {
        return;
      }

      switch (status) {
        case RealtimeSubscribeStatus.subscribed:
          _emit(realtime: RealtimeConnectionStatus.connected, clearError: true);

        case RealtimeSubscribeStatus.channelError:
          _emit(
            realtime: _state.transportAvailable
                ? RealtimeConnectionStatus.reconnecting
                : RealtimeConnectionStatus.disconnected,
            lastError: error == null
                ? 'Supabase Realtime channel error'
                : 'Supabase Realtime channel error: $error',
          );

        case RealtimeSubscribeStatus.timedOut:
          _emit(
            realtime: _state.transportAvailable
                ? RealtimeConnectionStatus.reconnecting
                : RealtimeConnectionStatus.disconnected,
            lastError: error == null
                ? 'Supabase Realtime connection timed out'
                : 'Supabase Realtime connection timed out: $error',
          );

        case RealtimeSubscribeStatus.closed:
          _emit(
            realtime: _state.transportAvailable
                ? RealtimeConnectionStatus.reconnecting
                : RealtimeConnectionStatus.disconnected,
            lastError: error == null
                ? 'Supabase Realtime connection closed'
                : 'Supabase Realtime connection closed: $error',
          );
      }
    });
  }

  // ===================================================================
  // STATE
  // ===================================================================

  void _emit({
    bool? initialized,
    bool? transportAvailable,
    RealtimeConnectionStatus? realtime,
    String? lastError,
    bool clearError = false,
  }) {
    if (_disposed) {
      return;
    }

    final next = NetworkState(
      initialized: initialized ?? _state.initialized,
      transportAvailable: transportAvailable ?? _state.transportAvailable,
      realtime: realtime ?? _state.realtime,
      lastError: clearError ? null : lastError ?? _state.lastError,
    );

    if (next == _state) {
      return;
    }

    _state = next;

    _stateController.add(next);
  }

  // ===================================================================
  // DISPOSE
  // ===================================================================

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    _disposed = true;

    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;

    final channel = _healthChannel;
    _healthChannel = null;

    if (channel != null) {
      try {
        await _supabase.removeChannel(channel);
      } catch (_) {
        // Dispose не должен падать из-за уже умершего соединения.
      }
    }

    await _stateController.close();
  }
}
