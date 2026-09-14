import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linsy/core/media/player_visibility.dart';
import 'package:linsy/features/room/player/player_engine.dart';
import 'package:linsy/features/room/player/player_engine_provider.dart';
import 'package:linsy/features/room/player/player_surface.dart';

void main() {
  testWidgets(
    'compact viewport remains playable; covering routes and background pause',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      var height = 220.0;
      late StateSetter update;
      late BuildContext pageContext;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playerEngineProvider.overrideWithValue(MockPlayerEngine()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setter) {
                  update = setter;
                  pageContext = context;
                  return SizedBox(
                    width: 360,
                    height: height,
                    child: const PlayerSurface(trackId: 'track'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));
      expect(playerVisibility.allowed, true);
      update(() => height = 100);
      await tester.pump(const Duration(milliseconds: 250));
      expect(playerVisibility.allowed, true);
      update(() => height = 0);
      await tester.pump(const Duration(milliseconds: 250));
      expect(playerVisibility.allowed, false);
      update(() => height = 220);
      await tester.pump(const Duration(milliseconds: 250));
      expect(playerVisibility.allowed, true);
      showDialog<void>(
        context: pageContext,
        builder: (_) => const AlertDialog(content: Text('Dialog')),
      );
      await tester.pump(const Duration(milliseconds: 250));
      expect(playerVisibility.allowed, false);
      Navigator.of(pageContext).pop();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 250));
      expect(playerVisibility.allowed, true);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(playerVisibility.allowed, false);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox());
      expect(playerVisibility.allowed, false);
    },
  );
}
