import 'package:linsy/features/room/presentation/widgets/room_social_bar.dart';
import 'package:linsy/features/room/presentation/controllers/room_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linsy/core/feedback/app_notice.dart';
import 'package:linsy/core/feedback/feedback_region.dart';
import 'package:linsy/core/media/player_visibility.dart';
import 'package:linsy/features/room/live_reactions/room_reaction_button.dart';
import 'package:linsy/features/room/player/player_engine.dart';
import 'package:linsy/features/room/player/player_engine_provider.dart';
import 'package:linsy/features/room/player/player_surface.dart';

void main() {
  testWidgets(
    'header notices and inline reactions do not cover or pause video',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      late BuildContext page;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playerEngineProvider.overrideWithValue(MockPlayerEngine()),
          ],
          child: MaterialApp(
            home: Scaffold(
              appBar: PreferredSize(
                preferredSize: const Size.fromHeight(kToolbarHeight),
                child: FeedbackRegion(child: AppBar(title: const Text('Room'))),
              ),
              body: Builder(
                builder: (context) {
                  page = context;
                  return const Column(
                    children: [
                      SizedBox(
                        height: 220,
                        child: PlayerSurface(trackId: 'track'),
                      ),
                      SizedBox(
                        height: 54,
                        child: RoomSocialBar(
                          roomState: RoomState.ready([]),
                          roomId: 'room',
                          currentUserId: 'user',
                          compact: true,
                        ),
                      ),
                      Expanded(child: SizedBox.expand()),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));
      expect(playerVisibility.allowed, isTrue);
      AppNotice.show(page, 'Copied');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(playerVisibility.allowed, isTrue);
      expect(
        tester.getBottomLeft(find.text('Copied')).dy,
        lessThanOrEqualTo(kToolbarHeight),
      );
      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      await tester.tap(find.byTooltip('React'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(playerVisibility.allowed, isTrue);
      expect(ModalRoute.of(page)!.isCurrent, isTrue);
      expect(find.byType(InkResponse), findsWidgets);
      expect(
        (tester.getCenter(find.byType(RoomReactionPicker)).dy -
                tester.getCenter(find.byTooltip('Close reactions')).dy)
            .abs(),
        lessThan(2),
      );
      await tester.tap(find.byTooltip('Close reactions'));
      await tester.pump();
      expect(playerVisibility.allowed, isTrue);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
