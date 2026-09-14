import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linsy/features/room/domain/models/room_member.dart';
import 'package:linsy/features/room/presentation/controllers/room_state.dart';
import 'package:linsy/features/room/presentation/widgets/room_invite_hint.dart';

void main() {
  for (final occupiedOnEntry in [false, true]) {
    testWidgets(
      'PiP remount preserves invite decision: occupied=$occupiedOnEntry',
      (tester) async {
        var session = RoomInviteSession();
        var pip = false;
        var occupied = occupiedOnEntry;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  if (pip) return const Text('PiP video');
                  return RoomInviteHint(
                    session: session,
                    roomId: 'room',
                    roomCode: 'CODE',
                    currentUserId: 'host',
                    roomState: RoomState.ready([
                      RoomMember(
                        userId: 'host',
                        role: RoomMemberRole.host,
                        joinedAt: DateTime(2026),
                      ),
                      if (occupied)
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
        if (!occupiedOnEntry) {
          expect(find.text('Music is better together'), findsOneWidget);
          await tester.tap(find.text('Later'));
          await tester.pumpAndSettle();
        }
        update(() => pip = true);
        await tester.pumpAndSettle();
        update(() {
          pip = false;
          occupied = false;
        });
        await tester.pumpAndSettle();
        expect(find.text('Music is better together'), findsNothing);
        // A genuinely new room session may show the hint again.
        update(() => session = RoomInviteSession());
        await tester.pumpAndSettle();
        expect(find.text('Music is better together'), findsOneWidget);
        await tester.tap(find.text('Later'));
        await tester.pumpAndSettle();
      },
    );
  }
}
