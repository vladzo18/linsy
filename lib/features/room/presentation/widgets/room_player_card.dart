import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:linsy/core/time/server_clock.dart';
import 'package:linsy/features/room/player/player_surface.dart';
import '../../domain/models/playback_state.dart';
import '../../domain/models/room_queue_item.dart';
import 'playback_timeline.dart';
import 'room_player_overlay_phase.dart';
import 'room_up_next_bar.dart';
import 'room_player_controls.dart';

class RoomPlayerCard extends ConsumerWidget {
  const RoomPlayerCard({
    super.key,
    this.compactHeader = false,
    required this.playback,
    required this.nextTrack,
    required this.livePositionMs,
    required this.canControlPlayback,
    required this.onPlayPause,
    required this.onNext,
    required this.onSeek,
    required this.onRequestPlayPause,
    required this.onRequestNext,
    required this.onRequestSeek,
  });

  final PlaybackState playback;
  final bool compactHeader;

  final RoomQueueItem? nextTrack;

  final int livePositionMs;

  final bool canControlPlayback;

  final Future<void> Function() onPlayPause;

  final Future<void> Function() onNext;

  final Future<void> Function(int positionMs) onSeek;

  final Future<void> Function() onRequestPlayPause;

  final Future<void> Function() onRequestNext;

  final Future<void> Function(int positionMs) onRequestSeek;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverClock = ref.watch(serverClockProvider).value;
    if (compactHeader && playback.trackId != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: PlayerSurface(trackId: playback.trackId),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    playback.title ?? 'Current track',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text(
                    playback.isPlaying ? 'Playing' : 'Paused',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: playback.isPlaying ? 'Pause' : 'Play',
                        onPressed: canControlPlayback
                            ? onPlayPause
                            : onRequestPlayPause,
                        icon: Icon(
                          playback.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Next track',
                        onPressed: canControlPlayback ? onNext : onRequestNext,
                        icon: const Icon(Icons.skip_next_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final trackId = playback.trackId;

        final hasTrack = trackId != null;

        final compact = constraints.maxWidth < 600;

        final durationMs = playback.durationMs ?? 0;

        final serverNow = serverClock?.now() ?? DateTime.now().toUtc();

        final authoritativePositionMs = playback.positionAt(serverNow);

        final authoritativeRemainingMs = durationMs > 0
            ? (durationMs - authoritativePositionMs).clamp(0, durationMs)
            : 0;

        final preparationDurationMs = nextTrack != null ? 3000 : 2000;

        final endingCountdownSeconds =
            ((authoritativeRemainingMs + preparationDurationMs) / 1000).ceil();

        final scheduledStartAt = playback.scheduledStartAt?.toUtc();

        final waitingForScheduledStart =
            playback.isPlaying &&
            scheduledStartAt != null &&
            serverNow.isBefore(scheduledStartAt);

        final transitionKind = playback.transitionKind;

        final PlayerOverlayPhase overlayPhase;

        if (waitingForScheduledStart && transitionKind == 'next') {
          overlayPhase = PlayerOverlayPhase.preparingNext;
        } else if (waitingForScheduledStart && transitionKind == 'repeat') {
          overlayPhase = PlayerOverlayPhase.preparingRepeat;
        } else if (hasTrack &&
            durationMs > 0 &&
            authoritativeRemainingMs <= 10000) {
          overlayPhase = PlayerOverlayPhase.ending;
        } else {
          overlayPhase = PlayerOverlayPhase.none;
        }

        final effectiveNext = canControlPlayback ? onNext : onRequestNext;

        return Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.none,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // VIDEO
              Expanded(
                child: ColoredBox(
                  color: Colors.black,
                  child: Center(
                    child: hasTrack
                        ? PlayerSurface(trackId: trackId)
                        : const EmptyPlayer(),
                  ),
                ),
              ),

              if (hasTrack && overlayPhase != PlayerOverlayPhase.none)
                RoomUpNextBar(
                  phase: overlayPhase,
                  // During preparation the playback row already contains the
                  // incoming track; the queue head points to the one after it.
                  nextTitle: waitingForScheduledStart
                      ? playback.title
                      : nextTrack?.title,
                  seconds: endingCountdownSeconds,
                  scheduledStartAt: scheduledStartAt,
                  now: () => serverClock?.now() ?? DateTime.now().toUtc(),
                ),

              // CURRENT TRACK CONTROLS
              if (hasTrack)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 12 : 18,
                    compact ? 6 : 8,
                    compact ? 12 : 18,
                    compact ? 7 : 10,
                  ),
                  child: Column(
                    children: [
                      PlaybackTimeline(
                        positionMs: livePositionMs,
                        durationMs: playback.durationMs ?? 0,
                        canControlPlayback: canControlPlayback,
                        onSeek: onSeek,
                        onRequestSeek: onRequestSeek,
                        compact: compact,
                      ),

                      SizedBox(height: compact ? 4 : 6),

                      PlayerControlsRow(
                        playback: playback,
                        isPlaying: playback.isPlaying,
                        canControlPlayback: canControlPlayback,
                        compact: compact,
                        onPlayPause: canControlPlayback
                            ? onPlayPause
                            : onRequestPlayPause,
                        onNext: canControlPlayback ? onNext : onRequestNext,
                      ),
                    ],
                  ),
                ),

              // NO CURRENT TRACK
              if (!hasTrack)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 12 : 18,
                    compact ? 8 : 10,
                    compact ? 12 : 18,
                    compact ? 8 : 10,
                  ),
                  child: StartQueueControls(
                    compact: compact,
                    onStart: effectiveNext,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
