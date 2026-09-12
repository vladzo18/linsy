import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linsy/features/profile/application/profile_store.dart';
import 'package:linsy/features/room/domain/models/room_member.dart';
import 'package:linsy/features/room/playback_history/application/room_playback_history_provider.dart';
import 'package:linsy/features/room/presentation/controllers/playback_controller.dart';
import 'package:linsy/features/room/presentation/controllers/queue_controller.dart';
import 'package:linsy/features/room/presentation/controllers/room_state.dart';
import 'package:linsy/features/room/presentation/widgets/room_queue_section.dart';

import 'support/room_test_fixtures.dart';

void main() {
  for (final expanded in [true]) {
    for (final scale in [1.0]) {
      for (final holdMs in [0]) {
        testWidgets(
          'Windows mouse drag stays inside the queue container, expanded=$expanded, hold=$holdMs, text=$scale',
          (tester) async {
            tester.view.physicalSize = const Size(1000, 800);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final queue = TestQueue();
            var panelDrags = 0;
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  queueControllerProvider('room').overrideWith(() => queue),
                  playbackControllerProvider(
                    'room',
                  ).overrideWith(TestPlayback.new),
                  roomPlaybackHistoryProvider(
                    'room',
                  ).overrideWith((ref) => Stream.value([])),
                  profileByIdProvider('user').overrideWithValue(null),
                ],
                child: MaterialApp(
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  theme: ThemeData(platform: TargetPlatform.windows),
                  home: Scaffold(
                    body: Align(
                      alignment: Alignment.bottomCenter,
                      child: SizedBox(
                        width: 700,
                        height: expanded ? 750 : 400,
                        child: GestureDetector(
                          onVerticalDragUpdate: expanded
                              ? null
                              : (_) => panelDrags++,
                          child: RoomQueueSection(
                            roomId: 'room',
                            currentUserId: 'user',
                            roomState: RoomState.ready([
                              RoomMember(
                                userId: 'user',
                                role: RoomMemberRole.host,
                                joinedAt: DateTime(2026),
                              ),
                            ]),
                            allowContentScroll: expanded,
                            isPanelExpanded: expanded,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            if (!expanded) {
              expect(
                tester
                    .getCenter(find.widgetWithText(FilledButton, 'Add track'))
                    .dx,
                closeTo(180, 1),
              );
            }
            final handles = find.byIcon(Icons.drag_indicator_rounded);
            expect(handles, findsAtLeastNWidgets(2));
            final start = tester.getCenter(handles.first);
            final target = tester.getRect(
              find.byType(DragTarget<String>).at(1),
            );
            final viewport = tester.getRect(find.byType(ListView));
            final visibleTarget = target.intersect(viewport);
            expect(visibleTarget.height, greaterThan(0));
            final end = visibleTarget.center;
            final gesture = await tester.startGesture(
              start,
              kind: PointerDeviceKind.mouse,
            );
            await tester.pump(Duration(milliseconds: holdMs));
            await gesture.moveBy(const Offset(0, 25));
            await tester.pump();
            final feedback = find.byWidgetPredicate(
              (widget) => widget is Opacity && widget.opacity == 0.94,
            );
            expect(feedback, findsOneWidget);
            final bounds = tester.getRect(feedback);
            expect(bounds.left, greaterThanOrEqualTo(viewport.left));
            expect(bounds.right, lessThanOrEqualTo(viewport.right - 14));
            await gesture.moveTo(end);
            await tester.pump();
            await gesture.up();
            await tester.pumpAndSettle();
            expect(queue.moved, '0');
            expect(queue.target, 1);
            expect(panelDrags, 0);
            expect(tester.takeException(), isNull);
          },
          variant: TargetPlatformVariant.only(TargetPlatform.windows),
        );
      }
    }
  }
}
