import 'package:flutter/services.dart';
import 'package:linsy/features/room/presentation/widgets/room_invite_hint.dart';
import 'package:linsy/features/room/presentation/widgets/request_member_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linsy/core/feedback/app_notice.dart';
import 'package:linsy/features/profile/application/profile_store.dart';
import 'package:linsy/features/room/domain/models/room_action_request.dart';
import 'package:linsy/features/room/domain/models/room_member.dart';
import 'package:linsy/features/room/presentation/controllers/action_request_controller.dart';
import 'package:linsy/features/room/presentation/controllers/queue_controller.dart';
import 'package:linsy/features/room/presentation/controllers/playback_controller.dart';
import 'package:linsy/features/room/presentation/controllers/room_state.dart';
import 'package:linsy/features/room/playback_history/application/room_playback_history_provider.dart';
import 'package:linsy/features/room/presentation/widgets/confirm_room_request.dart';
import 'package:linsy/features/room/presentation/widgets/room_queue_section.dart';
import 'support/room_test_fixtures.dart';

class _Requests extends ActionRequestController {
  _Requests() : super('room');
  int sent = 0;
  bool fail = false;
  @override
  Future<List<RoomActionRequest>> build() async => [];
  @override
  Future<void> createRequest({
    required RoomAction action,
    Map<String, dynamic>? payload,
  }) async {
    if (fail) throw StateError('offline');
    sent++;
  }
}

class _Queue extends TestQueue {
  String? removed;
  @override
  Future<void> removeItem(String itemId) async {
    removed = itemId;
  }
}

void main() {
  testWidgets('notices float at top, replace each other and dismiss', (
    tester,
  ) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              ctx = context;
              return const Text('Page content');
            },
          ),
        ),
      ),
    );
    AppNotice.show(ctx, 'First', kind: NoticeKind.success);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('First')).dy, lessThan(100));
    AppNotice.show(
      ctx,
      'Second',
      kind: NoticeKind.error,
      duration: const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();
    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Second'), findsNothing);
    AppNotice.show(ctx, 'Third');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.text('Third'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'request requires confirmation and never claims success on failure',
    (tester) async {
      final requests = _Requests();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            actionRequestControllerProvider(
              'room',
            ).overrideWith(() => requests),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, child) {
                  ref.watch(actionRequestControllerProvider('room'));
                  return TextButton(
                    onPressed: () => confirmRoomRequest(
                      context,
                      ref,
                      roomId: 'room',
                      action: RoomAction.pause,
                    ),
                    child: const Text('Pause'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pause'));
      await tester.pumpAndSettle();
      expect(requests.sent, 0);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(requests.sent, 0);
      await tester.tap(find.text('Pause'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send request'));
      await tester.pumpAndSettle();
      expect(requests.sent, 1);
      expect(
        find.text('Request sent to the host and moderators.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pumpAndSettle();
      requests.fail = true;
      await tester.tap(find.text('Pause'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send request'));
      await tester.pumpAndSettle();
      expect(requests.sent, 1);
      expect(
        find.text('Request sent to the host and moderators.'),
        findsNothing,
      );
      expect(
        find.text('Could not send the request. Please try again.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'invite hint is host-only, shown once and copies only after confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      var role = RoomMemberRole.member;
      var roomId = 'room';
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return RoomInviteHint(
                  roomId: roomId,
                  roomCode: 'ABC123',
                  currentUserId: 'user',
                  roomState: RoomState.ready([
                    RoomMember(
                      userId: 'user',
                      role: role,
                      joinedAt: DateTime(2026),
                    ),
                  ]),
                  child: const Text('Room content'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Music is better together'), findsNothing);
      update(() => role = RoomMemberRole.host);
      await tester.pumpAndSettle();
      expect(find.text('Music is better together'), findsNothing);
      update(() => roomId = 'host-room');
      await tester.pumpAndSettle();
      expect(find.text('Music is better together'), findsOneWidget);
      expect(copied, isNull);
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      update(() {});
      await tester.pumpAndSettle();
      expect(find.text('Music is better together'), findsNothing);
      update(() => roomId = 'another-room');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Copy room code'));
      await tester.pumpAndSettle();
      expect(copied, 'ABC123');
      expect(find.text('Room code copied'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final codeDelayed in [false, true]) {
    testWidgets(
      'leaving guests never trigger entry hint, delayed code=$codeDelayed',
      (tester) async {
        var guestPresent = true;
        String? code = codeDelayed ? null : 'ABC123';
        var roomId = 'occupied-room';
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return RoomInviteHint(
                    roomId: roomId,
                    roomCode: code,
                    currentUserId: 'host',
                    roomState: RoomState.ready([
                      RoomMember(
                        userId: 'host',
                        role: RoomMemberRole.host,
                        joinedAt: DateTime(2026),
                      ),
                      if (guestPresent)
                        RoomMember(
                          userId: 'guest',
                          role: RoomMemberRole.member,
                          joinedAt: DateTime(2026),
                        ),
                    ]),
                    child: const Text('Room'),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Music is better together'), findsNothing);
        update(() {
          guestPresent = false;
          code = 'ABC123';
        });
        await tester.pumpAndSettle();
        expect(find.text('Music is better together'), findsNothing);
        update(() => roomId = 'new-empty-room');
        await tester.pumpAndSettle();
        expect(find.text('Music is better together'), findsOneWidget);
        await tester.tap(find.text('Later'));
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets(
    'member requests has no duplicate action controls and only own requests',
    (tester) async {
      final requests = _Requests();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            actionRequestControllerProvider(
              'room',
            ).overrideWith(() => requests),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: MemberRequestsPanel(
                roomId: 'room',
                currentUserId: 'user',
                requestsState: AsyncData([
                  RoomActionRequest(
                    id: 'other',
                    roomId: 'room',
                    userId: 'someone-else',
                    action: RoomAction.pause,
                    payload: null,
                    status: RoomActionRequestStatus.pending,
                    createdAt: DateTime(2026),
                    resolvedAt: null,
                    resolvedBy: null,
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No pending requests'), findsOneWidget);
      expect(find.text('Pause'), findsNothing);
      expect(find.text('Play'), findsNothing);
      expect(find.text('Track'), findsNothing);
    },
  );

  for (final role in [RoomMemberRole.host, RoomMemberRole.member]) {
    testWidgets('queue permissions and deletion confirmation: $role', (
      tester,
    ) async {
      final queue = _Queue();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            queueControllerProvider('room').overrideWith(() => queue),
            playbackControllerProvider('room').overrideWith(TestPlayback.new),
            roomPlaybackHistoryProvider(
              'room',
            ).overrideWith((ref) => Stream.value([])),
            profileByIdProvider('user').overrideWithValue(null),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: RoomQueueSection(
                roomId: 'room',
                currentUserId: 'user',
                isPanelExpanded: true,
                roomState: RoomState.ready([
                  RoomMember(
                    userId: 'user',
                    role: role,
                    joinedAt: DateTime(2026),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Add track'), findsOneWidget);
      if (role == RoomMemberRole.member) {
        expect(find.byTooltip('Remove from queue'), findsNothing);
        expect(find.byIcon(Icons.drag_indicator_rounded), findsNothing);
      } else {
        await tester.tap(find.byTooltip('Remove from queue').first);
        await tester.pumpAndSettle();
        expect(queue.removed, isNull);
        expect(
          find.text('Remove “Long track title number 0” from the queue?'),
          findsOneWidget,
        );
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(queue.removed, isNull);
        await tester.tap(find.byTooltip('Remove from queue').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Remove'));
        await tester.pumpAndSettle();
        expect(queue.removed, '0');
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
