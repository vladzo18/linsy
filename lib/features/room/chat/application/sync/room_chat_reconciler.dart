import '../../domain/models/room_message.dart';

class RoomChatReconciler {
  const RoomChatReconciler._();

  static List<RoomMessage> reconcileLatest({
    required List<RoomMessage> beforeSync,
    required List<RoomMessage> afterSync,
    required List<RoomMessage> fetched,
    required int syncWindowSize,
  }) {
    final idsBeforeSync = beforeSync.map((message) => message.id).toSet();

    // Сообщения, которые Realtime доставил,
    // пока выполнялся SELECT.
    final concurrentMessages = afterSync
        .where((message) => !idsBeforeSync.contains(message.id))
        .toList();

    // Мы запрашиваем syncWindowSize + 1.
    //
    // Дополнительная строка позволяет понять,
    // существует ли история старше нашего sync-window.
    final hasOlderDatabaseMessages = fetched.length > syncWindowSize;

    final recovered = hasOlderDatabaseMessages
        ? fetched.sublist(fetched.length - syncWindowSize)
        : fetched;

    // ===================================================
    // DATABASE CONTAINS ALL ROOM MESSAGES
    // ===================================================
    //
    // Если получили <= syncWindowSize, мы знаем,
    // что SELECT охватил всю комнату.
    //
    // Поэтому БД полностью авторитетна и можно
    // удалить локальные сообщения, которых там больше нет.
    // ===================================================

    if (!hasOlderDatabaseMessages) {
      final byId = <String, RoomMessage>{};

      for (final message in recovered) {
        byId[message.id] = message;
      }

      // Realtime мог доставить новое сообщение
      // уже после момента SELECT.
      for (final message in concurrentMessages) {
        byId[message.id] = message;
      }

      final result = byId.values.toList()..sort(_compareMessages);

      return result;
    }

    // ===================================================
    // PAGINATED HISTORY EXISTS
    // ===================================================

    final byId = <String, RoomMessage>{};

    if (recovered.isNotEmpty) {
      final oldestRecovered = recovered.first;

      // Сохраняем историю, которую пользователь мог
      // догрузить через loadOlder().
      for (final message in afterSync) {
        if (_compareMessages(message, oldestRecovered) < 0) {
          byId[message.id] = message;
        }
      }
    }

    // Свежий участок из БД = source of truth.
    for (final message in recovered) {
      byId[message.id] = message;
    }

    // Сохраняем события, пришедшие параллельно с SELECT.
    for (final message in concurrentMessages) {
      byId[message.id] = message;
    }

    final result = byId.values.toList()..sort(_compareMessages);

    return result;
  }

  static int _compareMessages(RoomMessage a, RoomMessage b) {
    final timeCompare = a.createdAt.compareTo(b.createdAt);

    if (timeCompare != 0) {
      return timeCompare;
    }

    return a.id.compareTo(b.id);
  }
}
