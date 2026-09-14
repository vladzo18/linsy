import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:linsy/features/room/application/room_heartbeat.dart';

void main() {
  test(
    'does not overlap renewals and reports a missing session only once',
    () async {
      final pending = Completer<bool?>();
      var calls = 0;
      var expired = 0;
      final heartbeat = RoomHeartbeat(
        renew: () {
          calls++;
          return pending.future;
        },
        onExpired: () async {
          expired++;
        },
      );
      final first = heartbeat.pulse();
      await heartbeat.pulse();
      expect(calls, 1);
      pending.complete(false);
      await first;
      await heartbeat.pulse();
      expect(expired, 1);
      expect(calls, 1);
    },
  );

  test(
    'network errors and a not-yet-registered token do not expire a session',
    () async {
      var calls = 0;
      var expired = 0;
      final heartbeat = RoomHeartbeat(
        renew: () async {
          calls++;
          if (calls == 1) throw Exception('offline');
          return calls == 2 ? null : true;
        },
        onExpired: () async {
          expired++;
        },
      );
      await heartbeat.pulse();
      await heartbeat.pulse();
      await heartbeat.pulse();
      expect(calls, 3);
      expect(expired, 0);
      heartbeat.stop();
    },
  );

  test('late response after leaving cannot change the new screen', () async {
    final pending = Completer<bool?>();
    var expired = 0;
    final heartbeat = RoomHeartbeat(
      renew: () => pending.future,
      onExpired: () async {
        expired++;
      },
    );
    final work = heartbeat.pulse();
    heartbeat.stop();
    pending.complete(false);
    await work;
    expect(expired, 0);
  });

  testWidgets('renews periodically until the room session is disposed', (
    tester,
  ) async {
    var calls = 0;
    final heartbeat = RoomHeartbeat(
      renew: () async {
        calls++;
        return true;
      },
      onExpired: () async {},
    );
    heartbeat.start();
    await tester.pump();
    expect(calls, 1);
    await tester.pump(const Duration(seconds: 30));
    expect(calls, 2);
    heartbeat.stop();
    await tester.pump(const Duration(seconds: 60));
    expect(calls, 2);
  });
}
