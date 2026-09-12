import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linsy/features/profile/application/profile_store.dart';
import 'package:linsy/features/room/domain/models/room_member.dart';
import 'package:linsy/features/room/playback_history/application/room_playback_history_provider.dart';
import 'package:linsy/features/room/playback_history/domain/models/room_playback_history_item.dart';
import 'package:linsy/features/room/playback_history/presentation/room_playback_history_view.dart';
import 'package:linsy/features/room/presentation/controllers/playback_controller.dart';
import 'package:linsy/features/room/presentation/controllers/queue_controller.dart';
import 'package:linsy/features/room/presentation/controllers/room_state.dart';
import 'package:linsy/features/room/presentation/widgets/queue_collapsed_preview.dart';
import 'package:linsy/features/room/presentation/widgets/room_queue_section.dart';

import 'support/room_test_fixtures.dart';

void main() {
  for (final config in [
    (320.0, 180.0, 1.3),
    (360.0, 400.0, 1.0),
    (360.0, 100.0, 1.0),
    (800.0, 210.0, 1.3),
  ]) {
    testWidgets('closed queue is an entry point, size=$config', (tester) async {
      tester.view.physicalSize = Size(config.$1, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var expanded = false;
      double? contentHeight;
      late StateSetter update;
      var handoffs = 0;
      final history = List.generate(
        3,
        (i) => RoomPlaybackHistoryItem(
          id: 'h$i',
          roomId: 'room',
          source: 'youtube',
          trackId: 'h$i',
          title: 'History track $i',
          thumbnailUrl: null,
          durationMs: 180000,
          playedAt: DateTime(2026, 9, 11),
          playCount: 1,
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            queueControllerProvider('room').overrideWith(TestQueue.new),
            playbackControllerProvider('room').overrideWith(TestPlayback.new),
            roomPlaybackHistoryProvider(
              'room',
            ).overrideWith((ref) => Stream.value(history)),
            profileByIdProvider('user').overrideWithValue(null),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(config.$3)),
              child: child!,
            ),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return Align(
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      height: expanded ? 750 : config.$2,
                      child: RoomQueueSection(
                        onQueueContentHeight: (height) =>
                            contentHeight = height,
                        roomId: 'room',
                        currentUserId: 'user',
                        roomState: RoomState.ready([
                          RoomMember(
                            userId: 'user',
                            role: RoomMemberRole.host,
                            joinedAt: DateTime(2026),
                          ),
                        ]),
                        isPanelExpanded: expanded,
                        allowContentScroll: expanded,
                        onExpand: () => setState(() => expanded = true),
                        onScrollHandoff: (delta, metrics) {
                          if (delta > 0 &&
                              metrics.pixels <= metrics.minScrollExtent + 1) {
                            handoffs++;
                            return true;
                          }
                          return false;
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(QueueCollapsedPreview), findsOneWidget);
      expect(contentHeight, isNotNull);
      if (config.$2 == 400) {
        // Natural height is reported rather than stretching to the viewport.
        expect(contentHeight!, lessThan(260));
      }
      expect(find.byType(ListView), findsNothing);
      expect(find.text('Long track title number 0'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Open queue'));
      await tester.tap(find.text('Open queue'));
      await tester.pumpAndSettle();
      expect(find.byType(QueueCollapsedPreview), findsNothing);
      expect(find.byIcon(Icons.drag_indicator_rounded), findsWidgets);

      await tester.tap(find.byTooltip('Playback history'));
      await tester.pumpAndSettle();
      expect(find.byType(RoomPlaybackHistoryView), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView), const Offset(0, 80));
      await tester.pumpAndSettle();
      expect(handoffs, greaterThan(0));

      update(() => expanded = false);
      await tester.pumpAndSettle();
      expect(find.byType(ListView), findsNothing);
      expect(find.textContaining('Playback history ·'), findsOneWidget);
      await tester.ensureVisible(find.text('Open history'));
      await tester.tap(find.text('Open history'));
      await tester.pumpAndSettle();
      expect(find.byType(RoomPlaybackHistoryView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
