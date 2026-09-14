import 'package:linsy/features/room/presentation/widgets/room_player_overlay_phase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linsy/core/time/server_clock.dart';
import 'package:linsy/features/library/application/saved_tracks_controller.dart';
import 'package:linsy/features/library/domain/models/saved_track.dart';
import 'package:linsy/features/room/domain/models/playback_state.dart';
import 'package:linsy/features/room/domain/models/room_queue_item.dart';
import 'package:linsy/features/room/player/player_engine.dart';
import 'package:linsy/features/room/player/player_engine_provider.dart';
import 'package:linsy/features/room/player/player_volume_controller.dart';
import 'package:linsy/features/room/presentation/widgets/room_player_card.dart';
import 'package:linsy/features/room/player/player_surface.dart';
import 'package:linsy/features/room/presentation/widgets/room_up_next_bar.dart';

class TestVolume extends PlayerVolumeController {
  @override
  double build() => 0.5;
}

class TestSavedTracks extends SavedTracksController {
  @override
  Future<List<SavedTrack>> build() async => [];
}

void main() {
  for (final preparing in [false, true]) {
    for (final compactHeader in [false, true]) {
      for (final width in [320.0, 360.0, 412.0]) {
        testWidgets(
          'Player layout width=$width compact=$compactHeader preparing=$preparing',
          (tester) async {
            tester.view.physicalSize = Size(width, 800);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final engine = MockPlayerEngine();
            addTearDown(engine.dispose);
            var nextPressed = false;
            final now = DateTime.now().toUtc();
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  serverClockProvider.overrideWithValue(const AsyncLoading()),
                  playerEngineProvider.overrideWithValue(engine),
                  playerVolumeProvider.overrideWith(TestVolume.new),
                  savedTracksControllerProvider.overrideWith(
                    TestSavedTracks.new,
                  ),
                ],
                child: MaterialApp(
                  home: Scaffold(
                    body: SizedBox(
                      height: compactHeader ? 110 : 380,
                      child: RoomPlayerCard(
                        compactHeader: compactHeader,
                        playback: PlaybackState(
                          trackId: 'current',
                          source: 'youtube',
                          title: 'Current song',
                          thumbnailUrl: null,
                          durationMs: 180000,
                          addedBy: null,
                          isPlaying: true,
                          positionMs: preparing ? 0 : 175000,
                          updatedAt: now,
                          scheduledStartAt: preparing
                              ? now.add(const Duration(seconds: 30))
                              : null,
                          transitionKind: preparing ? 'next' : null,
                          updatedBy: null,
                        ),
                        nextTrack: RoomQueueItem(
                          id: 'next',
                          roomId: 'room',
                          source: 'youtube',
                          trackId: 'next',
                          title:
                              'A long next track title spanning multiple lines',
                          thumbnailUrl: null,
                          durationMs: 180000,
                          position: 0,
                          addedBy: 'user',
                          createdAt: now,
                        ),
                        livePositionMs: 175000,
                        canControlPlayback: true,
                        onPlayPause: () async {},
                        onNext: () async {
                          nextPressed = true;
                        },
                        onSeek: (_) async {},
                        onRequestPlayPause: () async {},
                        onRequestNext: () async {},
                        onRequestSeek: (_) async {},
                      ),
                    ),
                  ),
                ),
              ),
            );
            // Metadata must be outside the video, including during countdown.
            await tester.pump(const Duration(milliseconds: 400));
            expect(
              find.text(preparing ? 'STARTING' : 'UP NEXT'),
              compactHeader ? findsNothing : findsOneWidget,
            );
            expect(tester.takeException(), isNull);
            if (!compactHeader) {
              final bar = tester.widget<RoomUpNextBar>(
                find.byType(RoomUpNextBar),
              );
              expect(
                bar.nextTitle,
                preparing
                    ? 'Current song'
                    : 'A long next track title spanning multiple lines',
              );
              expect(
                tester.getRect(find.byType(RoomUpNextBar)).top,
                greaterThanOrEqualTo(
                  tester.getRect(find.byType(PlayerSurface)).bottom,
                ),
              );
            }
            await tester.tap(find.byTooltip('Next track'));
            await tester.pump();
            expect(nextPressed, isTrue);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          },
        );
      }
    }
  }
  testWidgets('preparation disappears at start without parent updates', (
    tester,
  ) async {
    var now = DateTime.utc(2026);
    final start = now.add(const Duration(seconds: 3));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoomUpNextBar(
            phase: PlayerOverlayPhase.preparingNext,
            nextTitle: 'Incoming song',
            seconds: 3,
            scheduledStartAt: start,
            now: () => now,
          ),
        ),
      ),
    );
    expect(find.text('Incoming song'), findsOneWidget);
    now = start;
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Incoming song'), findsNothing);
    expect(find.text('0s'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
