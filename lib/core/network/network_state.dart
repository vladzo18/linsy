enum NetworkStatus { online, offline, reconnecting }

enum RealtimeConnectionStatus { connected, reconnecting, disconnected }

class NetworkState {
  const NetworkState({
    required this.initialized,
    required this.transportAvailable,
    required this.realtime,
    this.lastError,
  });

  const NetworkState.initial()
    : initialized = false,
      transportAvailable = false,
      realtime = RealtimeConnectionStatus.disconnected,
      lastError = null;

  /// Получили ли мы уже первое реальное состояние сети.
  final bool initialized;

  /// Есть ли вообще сетевой интерфейс:
  /// Wi-Fi / Ethernet / Mobile / VPN / etc.
  ///
  /// Это НЕ означает, что Supabase реально доступен.
  final bool transportAvailable;

  /// Состояние именно Supabase Realtime.
  final RealtimeConnectionStatus realtime;

  /// Последняя диагностическая ошибка сетевой инфраструктуры.
  ///
  /// Бизнес-логика не должна принимать решения на основе этого поля.
  final String? lastError;

  NetworkStatus get status {
    if (!initialized) {
      return NetworkStatus.reconnecting;
    }

    if (!transportAvailable) {
      return NetworkStatus.offline;
    }

    if (realtime == RealtimeConnectionStatus.connected) {
      return NetworkStatus.online;
    }

    return NetworkStatus.reconnecting;
  }

  bool get isOnline => status == NetworkStatus.online;

  bool get isOffline => status == NetworkStatus.offline;

  bool get isReconnecting => status == NetworkStatus.reconnecting;

  @override
  bool operator ==(Object other) {
    return other is NetworkState &&
        other.initialized == initialized &&
        other.transportAvailable == transportAvailable &&
        other.realtime == realtime &&
        other.lastError == lastError;
  }

  @override
  int get hashCode {
    return Object.hash(initialized, transportAvailable, realtime, lastError);
  }

  @override
  String toString() {
    return 'NetworkState('
        'status: $status, '
        'transportAvailable: $transportAvailable, '
        'realtime: $realtime, '
        'lastError: $lastError'
        ')';
  }
}
