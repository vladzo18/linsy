import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linsy/features/room/player/room_pip.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('linsy/pip');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'Android forwards eligibility and follows native PiP entry and exit',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(roomPipProvider.notifier);
      await controller.configure(true);
      await controller.configure(false);
      expect(calls.map((call) => call.arguments['enabled']), [true, false]);
      for (final active in [true, false]) {
        await messenger.handlePlatformMessage(
          'linsy/pip',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('changed', active),
          ),
          (_) {},
        );
        expect(container.read(roomPipProvider), active);
      }
    },
  );

  test('Windows does not configure Android PiP', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    var calls = 0;
    messenger.setMockMethodCallHandler(channel, (_) async {
      calls++;
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(roomPipProvider.notifier).configure(true);
    expect(calls, 0);
    expect(container.read(roomPipProvider), false);
  });
}
