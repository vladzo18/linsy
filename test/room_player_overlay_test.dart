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

class TestVolume extends PlayerVolumeController {
  @override
  double build() => 0.5;
}

class TestSavedTracks extends SavedTracksController {
  @override
  Future<List<SavedTrack>> build() async => [];
}

void main() {
  for (final width in [320.0, 360.0, 412.0]) {
    testWidgets('UP NEXT fits narrow player at width $width', (tester) async {
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
            savedTracksControllerProvider.overrideWith(TestSavedTracks.new),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 280,
                child: RoomPlayerCard(
                  playback: PlaybackState(
                    trackId: 'current',
                    source: 'youtube',
                    title: 'Current song',
                    thumbnailUrl: null,
                    durationMs: 180000,
                    addedBy: null,
                    isPlaying: true,
                    positionMs: 175000,
                    updatedAt: now,
                    scheduledStartAt: null,
                    transitionKind: null,
                    updatedBy: null,
                  ),
                  nextTrack: RoomQueueItem(
                    id: 'next',
                    roomId: 'room',
                    source: 'youtube',
                    trackId: 'next',
                    title: 'A long next track title spanning multiple lines',
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
      // The overlay has a repeating ambient animation; do not pumpAndSettle.
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('UP NEXT'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Play next now'));
      await tester.pump();
      expect(nextPressed, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
