import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linsy/core/feedback/app_notice.dart';
import 'package:linsy/core/media/player_visibility.dart';
import 'package:linsy/core/platform/windows/window_service.dart';
import 'package:linsy/features/room/player/player_engine.dart';
import 'package:linsy/features/room/player/player_engine_provider.dart';
import 'package:linsy/features/room/player/player_surface.dart';

void main() {
  testWidgets(
    'private Windows playback survives focus loss, minimize and blockers',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playerEngineProvider.overrideWithValue(MockPlayerEngine()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 360,
                height: 220,
                child: PlayerSurface(trackId: 'track'),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(playerVisibility.allowed, isTrue);
      expect(find.textContaining('Playback paused locally'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      expect(playerVisibility.allowed, isTrue);
      final release = playerVisibility.block();
      expect(playerVisibility.allowed, isTrue);
      release();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(playerVisibility.allowed, isTrue);
      expect(find.textContaining('Playback paused locally'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  test('window focus releases only its own minimize blocker', () {
    final service = PlatformWindowService(onCloseRequested: () async {});
    final releaseOther = playerVisibility.block();
    service.onWindowMinimize();
    service.onWindowMinimize();
    service.onWindowFocus();
    expect(playerVisibility.blocked, isTrue);
    releaseOther();
    expect(playerVisibility.blocked, isFalse);
    service.onWindowRestore();
    expect(playerVisibility.blocked, isFalse);
  });

  testWidgets(
    'notice releases playback even when animation tickers are disabled',
    (tester) async {
      late BuildContext page;
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => TickerMode(enabled: false, child: child!),
          home: Builder(
            builder: (context) {
              page = context;
              return const Scaffold();
            },
          ),
        ),
      );
      AppNotice.show(
        page,
        'Copied',
        duration: const Duration(milliseconds: 100),
      );
      await tester.pump();
      expect(playerVisibility.blocked, isTrue);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      expect(find.text('Copied'), findsNothing);
      expect(playerVisibility.blocked, isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
