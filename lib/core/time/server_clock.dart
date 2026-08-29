import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServerClock {
  final SupabaseClient _client;

  Duration _offset = Duration.zero;

  ServerClock(this._client);

  DateTime now() {
    return DateTime.now()
        .toUtc()
        .add(_offset);
  }

  Duration get offset => _offset;

  Future<void> synchronize({
    int samples = 5,
  }) async {
    Duration? bestRtt;
    Duration? bestOffset;

    for (var i = 0; i < samples; i++) {
      final startedAt =
          DateTime.now().toUtc();

      final response =
          await _client.rpc(
        'get_server_time',
      );

      final finishedAt =
          DateTime.now().toUtc();

      if (response is! String) {
        throw StateError(
          'Invalid get_server_time response.',
        );
      }

      final serverTime =
          DateTime.parse(
        response,
      ).toUtc();

      final rtt =
          finishedAt.difference(
        startedAt,
      );

      // Считаем, что ответ сервера пришёл примерно
      // посередине между отправкой и получением.
      final midpointUs =
          startedAt.microsecondsSinceEpoch +
              rtt.inMicroseconds ~/ 2;

      final midpoint =
          DateTime.fromMicrosecondsSinceEpoch(
        midpointUs,
        isUtc: true,
      );

      final offset =
          serverTime.difference(
        midpoint,
      );

      if (bestRtt == null ||
          rtt < bestRtt) {
        bestRtt = rtt;
        bestOffset = offset;
      }

      await Future<void>.delayed(
        const Duration(
          milliseconds: 80,
        ),
      );
    }

    _offset =
        bestOffset ?? Duration.zero;

    debugPrint(
      '[ServerClock] '
      'offset=${_offset.inMilliseconds} ms | '
      'rtt=${bestRtt?.inMilliseconds ?? 0} ms',
    );
  }
}

final serverClockProvider =
    FutureProvider<ServerClock>(
  (ref) async {
    final clock = ServerClock(
      Supabase.instance.client,
    );

    await clock.synchronize();

    return clock;
  },
);