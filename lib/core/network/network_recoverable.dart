import 'network_state.dart';

abstract interface class NetworkRecoverable {
  Future<void> recoverNetwork(NetworkRecoveryContext context);
}

class NetworkRecoveryContext {
  const NetworkRecoveryContext({
    required this.previousState,
    required this.currentState,
    required this.recoveredAt,
  });

  final NetworkState previousState;

  final NetworkState currentState;

  final DateTime recoveredAt;
}
