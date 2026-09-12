import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linsy/features/profile/application/profile_store.dart';
import 'package:linsy/features/room/chat/domain/models/room_message.dart';
import 'package:linsy/features/room/chat/presentation/widgets/room_message_bubble.dart';
import 'package:linsy/features/room/presentation/widgets/horizontal_scroll_fade.dart';
import 'package:linsy/features/room/presentation/widgets/queue_collapsed_preview.dart';
import 'package:linsy/features/room/domain/models/playback_state.dart';

void main() {
  testWidgets('participant fades follow overflow, scroll and resize', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    Future<void> show(double width) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: width,
              height: 64,
              child: HorizontalScrollFade(
                child: ListView(
                  controller: controller,
                  scrollDirection: Axis.horizontal,
                  children: List.generate(
                    4,
                    (i) => SizedBox(width: 100, child: Text('User $i')),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    final left = find.byKey(const ValueKey('scroll-fade-left'));
    final right = find.byKey(const ValueKey('scroll-fade-right'));
    await show(240);
    expect(left, findsNothing);
    expect(right, findsOneWidget);
    controller.jumpTo(80);
    await tester.pumpAndSettle();
    expect(left, findsOneWidget);
    expect(right, findsOneWidget);
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(left, findsOneWidget);
    expect(right, findsNothing);
    await show(600);
    expect(left, findsNothing);
    expect(right, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closed queue retains current playback and centered add action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var expanded = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [profileByIdProvider('user').overrideWithValue(null)],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 230,
              child: QueueCollapsedPreview(
                playbackState: AsyncData(
                  PlaybackState(
                    trackId: 'track',
                    source: 'youtube',
                    title: 'Current song',
                    thumbnailUrl: null,
                    durationMs: 180000,
                    addedBy: 'user',
                    isPlaying: true,
                    positionMs: 0,
                    updatedAt: DateTime(2026),
                    scheduledStartAt: null,
                    transitionKind: null,
                    updatedBy: null,
                  ),
                ),
                items: const [],
                showingHistory: false,
                historyCount: 1,
                onExpand: () => expanded = true,
                onAddTrack: () {},
                onToggleHistory: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Current song'), findsOneWidget);
    final titleBottom = tester.getBottomLeft(find.text('Current song')).dy;
    final addRect = tester.getRect(find.widgetWithText(FilledButton, 'Add track'));
    final statsRect = tester.getRect(find.textContaining('Queue ·'));
    final expandRect = tester.getRect(find.text('Open queue'));
    expect(titleBottom, lessThan(addRect.top));
    expect(addRect.bottom, lessThan(statsRect.top));
    expect(statsRect.bottom, lessThan(expandRect.top));
    expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsNothing);
    expect(find.textContaining('Playing · Added by'), findsOneWidget);
    expect(
      tester.getCenter(find.widgetWithText(FilledButton, 'Add track')).dx,
      closeTo(160, 1),
    );
    await tester.drag(find.text('Current song'), const Offset(0, -80));
    await tester.pumpAndSettle();
    expect(expanded, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('message text stays attached to bubbles during fast flings', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [profileByIdProvider('user').overrideWithValue(null)],
        child: MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              controller: controller,
              itemCount: 80,
              itemBuilder: (context, index) => RoomMessageBubble(
                key: ValueKey(index),
                message: RoomMessage(
                  id: '$index',
                  roomId: 'room',
                  userId: 'user',
                  content: 'Message $index\nSecond line',
                  createdAt: DateTime(2026),
                ),
                isOwn: true,
                currentUserId: 'user',
                reactions: const [],
                onReply: () {},
                onToggleReaction: (_) async {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    void checkText() {
      for (final element in find.byType(SelectionArea).evaluate()) {
        final selection = find.byWidget(element.widget);
        final bubble = find.ancestor(
          of: selection,
          matching: find.byType(MenuAnchor),
        );
        final textRect = tester.getRect(selection);
        final bubbleRect = tester.getRect(bubble);
        expect(textRect.top - bubbleRect.top, closeTo(9, 0.01));
        expect(textRect.bottom, lessThan(bubbleRect.bottom));
      }
      expect(tester.takeException(), isNull);
    }

    for (final dy in [-900.0, 900.0, -900.0]) {
      await tester.fling(find.byType(ListView), Offset(0, dy), 5000);
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        checkText();
      }
      await tester.pumpAndSettle();
      checkText();
    }
  });
}
