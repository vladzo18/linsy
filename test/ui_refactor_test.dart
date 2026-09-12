import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:linsy/features/home/presentation/widgets/home_room_actions.dart';
import 'package:linsy/features/profile/application/profile_store.dart';
import 'package:linsy/features/room/chat/domain/models/room_message.dart';
import 'package:linsy/features/room/chat/domain/models/room_message_reaction.dart';
import 'package:linsy/features/room/chat/presentation/widgets/room_message_bubble.dart';

void main() {
  testWidgets(
    'message reaction and reply callbacks survive component extraction',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? selectedReaction;
      var replied = false;
      final now = DateTime(2026, 9, 11, 15, 30);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [profileByIdProvider('user').overrideWithValue(null)],
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: RoomMessageBubble(
                  message: RoomMessage(
                    id: 'message',
                    roomId: 'room',
                    userId: 'user',
                    content: 'Listen to this song',
                    createdAt: now,
                    reply: const RoomMessageReplyPreview(
                      messageId: 'previous',
                      userId: 'user',
                      content: 'Previous message',
                    ),
                  ),
                  isOwn: true,
                  currentUserId: 'user',
                  reactions: [
                    RoomMessageReaction(
                      messageId: 'message',
                      userId: 'user',
                      reaction: 'heart',
                      createdAt: now,
                    ),
                  ],
                  onReply: () => replied = true,
                  onToggleReaction: (value) async => selectedReaction = value,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Previous message'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('❤️'));
      await tester.pumpAndSettle();
      expect(selectedReaction, 'heart');
      // Text itself supports selection; the bubble padding opens its actions.
      await tester.longPressAt(
        tester.getTopLeft(find.byType(MenuAnchor)) + const Offset(5, 5),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Reply'));
      await tester.pumpAndSettle();
      expect(replied, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [360.0, 1000.0]) {
    testWidgets('home action navigation at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(
              body: Padding(
                padding: EdgeInsets.all(16),
                child: HomeRoomActions(),
              ),
            ),
          ),
          GoRoute(
            path: '/room/create',
            builder: (_, _) => const Scaffold(body: Text('Create destination')),
          ),
          GoRoute(
            path: '/room/join',
            builder: (_, _) => const Scaffold(body: Text('Join destination')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Create room'));
      await tester.pumpAndSettle();
      expect(find.text('Create destination'), findsOneWidget);
      router.go('/');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Join room'));
      await tester.pumpAndSettle();
      expect(find.text('Join destination'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
