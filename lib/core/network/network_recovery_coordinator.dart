import 'dart:async';
import 'dart:developer' as developer;

import 'network_monitor.dart';
import 'network_recoverable.dart';
import 'network_state.dart';

class NetworkRecoveryCoordinator {
  NetworkRecoveryCoordinator(this._networkMonitor);

  final NetworkMonitor _networkMonitor;

  final Set<NetworkRecoverable> _recoverables = {};

  final StreamController<NetworkRecoveryContext> _recoveryController =
      StreamController<NetworkRecoveryContext>.broadcast(sync: true);

  StreamSubscription<NetworkState>? _subscription;

  NetworkState? _previousState;

  bool _started = false;
  bool _disposed = false;

  bool _recovering = false;

  NetworkRecoveryContext? _pendingRecovery;

  Stream<NetworkRecoveryContext> get recoveryEvents =>
      _recoveryController.stream;

  // ===================================================================
  // START
  // ===================================================================

  Future<void> start() async {
    if (_started || _disposed) {
      return;
    }

    _started = true;

    // Текущее состояние запоминаем как baseline.
    //
    // Поэтому обычный запуск приложения при хорошем интернете
    // НЕ считается "recovery".
    _previousState = _networkMonitor.state;

    _subscription = _networkMonitor.states.listen(_handleNetworkState);
  }

  // ===================================================================
  // REGISTER
  // ===================================================================

  void Function() register(NetworkRecoverable recoverable) {
    _recoverables.add(recoverable);

    return () {
      _recoverables.remove(recoverable);
    };
  }

  // ===================================================================
  // NETWORK EVENT
  // ===================================================================

  void _handleNetworkState(NetworkState current) {
    final previous = _previousState;

    _previousState = current;

    if (previous == null) {
      return;
    }

    final wasUnavailable = previous.status != NetworkStatus.online;

    final isNowOnline = current.status == NetworkStatus.online;

    if (!wasUnavailable || !isNowOnline) {
      return;
    }

    final context = NetworkRecoveryContext(
      previousState: previous,
      currentState: current,
      recoveredAt: DateTime.now().toUtc(),
    );

    // Отдельное глобальное событие.
    _recoveryController.add(context);

    unawaited(_scheduleRecovery(context));
  }

  // ===================================================================
  // RECOVERY
  // ===================================================================

  Future<void> _scheduleRecovery(NetworkRecoveryContext context) async {
    // Если recovery уже идёт, не запускаем второй параллельно.
    //
    // Но запоминаем, что после текущего нужно выполнить ещё один.
    if (_recovering) {
      _pendingRecovery = context;
      return;
    }

    _recovering = true;

    var current = context;

    try {
      while (true) {
        _pendingRecovery = null;

        final recoverables = List<NetworkRecoverable>.from(_recoverables);

        await Future.wait(
          recoverables.map(
            (recoverable) => _recoverSafely(recoverable, current),
          ),
        );

        final pending = _pendingRecovery;

        if (pending == null) {
          break;
        }

        current = pending;
      }
    } finally {
      _recovering = false;
    }
  }

  Future<void> _recoverSafely(
    NetworkRecoverable recoverable,
    NetworkRecoveryContext context,
  ) async {
    try {
      await recoverable.recoverNetwork(context);
    } catch (error, stackTrace) {
      // Ошибка одного модуля не должна мешать
      // восстановлению остальных.
      developer.log(
        'Network recovery failed for '
        '${recoverable.runtimeType}',
        name: 'linsy.network',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  // ===================================================================
  // DISPOSE
  // ===================================================================

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    _disposed = true;

    await _subscription?.cancel();
    _subscription = null;

    _recoverables.clear();

    await _recoveryController.close();
  }
}
