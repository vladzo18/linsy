import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linsy/core/platform/system_media_volume.dart';
import 'package:linsy/features/room/presentation/widgets/player_volume_control.dart';

void main() {
  testWidgets(
    'Android indicator follows system mute and volume without a slider',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final volume = StreamController<double>();
      addTearDown(volume.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            systemMediaVolumeProvider.overrideWith((ref) => volume.stream),
          ],
          child: const MaterialApp(home: Scaffold(body: PlayerVolumeControl())),
        ),
      );
      volume.add(0);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
      volume.add(0.7);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
      expect(find.byIcon(Icons.volume_off_rounded), findsNothing);
      await tester.tap(find.byIcon(Icons.volume_up_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(Slider), findsNothing);
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
