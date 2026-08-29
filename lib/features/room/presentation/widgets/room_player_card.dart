import 'package:flutter/material.dart';
import 'package:linsy/features/room/player/player_surface.dart';

import '../../domain/models/playback_state.dart';
import 'playback_timeline.dart';
import 'player_volume_control.dart';

class RoomPlayerCard extends StatelessWidget {
  const RoomPlayerCard({
    super.key,
    required this.playback,
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

  final int livePositionMs;

  final bool canControlPlayback;

  final Future<void> Function() onPlayPause;

  final Future<void> Function() onNext;

  final Future<void> Function(int positionMs) onSeek;

  final Future<void> Function() onRequestPlayPause;

  final Future<void> Function() onRequestNext;

  final Future<void> Function(int positionMs) onRequestSeek;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackId = playback.trackId;

        final hasTrack = trackId != null;

        final compact = constraints.maxWidth < 600;

        return Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ===================================================
              // VIDEO
              // ===================================================
              Expanded(
                child: ColoredBox(
                  color: Colors.black,
                  child: Center(
                    child: hasTrack
                        ? AspectRatio(
                            aspectRatio: 16 / 9,
                            child: PlayerSurface(trackId: trackId),
                          )
                        : const _EmptyPlayer(),
                  ),
                ),
              ),

              // ===================================================
              // CURRENT TRACK CONTROLS
              // ===================================================
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
                      // ===========================================
                      // TIMELINE
                      // ===========================================
                      PlaybackTimeline(
                        positionMs: livePositionMs,
                        durationMs: playback.durationMs ?? 0,
                        canControlPlayback: canControlPlayback,
                        onSeek: onSeek,
                        onRequestSeek: onRequestSeek,
                        compact: compact,
                      ),

                      SizedBox(height: compact ? 4 : 6),

                      // ===========================================
                      // BUTTONS
                      // ===========================================
                      _PlayerControlsRow(
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

              // ===================================================
              // NO CURRENT TRACK
              // ===================================================
              if (!hasTrack && canControlPlayback)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 12 : 18,
                    compact ? 8 : 10,
                    compact ? 12 : 18,
                    compact ? 8 : 10,
                  ),
                  child: _StartQueueControls(compact: compact, onStart: onNext),
                ),
            ],
          ),
        );
      },
    );
  }
}

// =====================================================================
// START QUEUE
// =====================================================================

class _StartQueueControls extends StatelessWidget {
  const _StartQueueControls({required this.compact, required this.onStart});

  final bool compact;

  final Future<void> Function() onStart;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 44 : 50,
      child: Row(
        children: [
          // Оставляем volume слева,
          // чтобы нижняя панель не
          // прыгала при старте трека.
          SizedBox(
            width: compact ? 42 : 48,
            child: const Align(
              alignment: Alignment.centerLeft,
              child: PlayerVolumeControl(),
            ),
          ),

          Expanded(
            child: Center(
              child: FilledButton.tonalIcon(
                onPressed: () async {
                  await onStart();
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start queue'),
              ),
            ),
          ),

          SizedBox(width: compact ? 42 : 48),
        ],
      ),
    );
  }
}

// =====================================================================
// CONTROLS ROW
// =====================================================================

class _PlayerControlsRow extends StatelessWidget {
  const _PlayerControlsRow({
    required this.isPlaying,
    required this.canControlPlayback,
    required this.compact,
    required this.onPlayPause,
    required this.onNext,
  });

  final bool isPlaying;

  final bool canControlPlayback;

  final bool compact;

  final Future<void> Function() onPlayPause;

  final Future<void> Function() onNext;

  @override
  Widget build(BuildContext context) {
    final sideWidth = compact ? 42.0 : 48.0;

    return SizedBox(
      height: compact ? 44 : 50,
      child: Row(
        children: [
          // =======================================================
          // VOLUME
          // =======================================================
          SizedBox(
            width: sideWidth,
            child: const Align(
              alignment: Alignment.centerLeft,
              child: PlayerVolumeControl(),
            ),
          ),

          // =======================================================
          // PLAYBACK
          // =======================================================
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Tooltip(
                  message: canControlPlayback
                      ? isPlaying
                            ? 'Pause'
                            : 'Play'
                      : isPlaying
                      ? 'Request pause'
                      : 'Request play',
                  child: IconButton.filledTonal(
                    onPressed: () async {
                      await onPlayPause();
                    },
                    icon: Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    iconSize: compact ? 24 : 26,
                    padding: EdgeInsets.all(compact ? 9 : 11),
                  ),
                ),

                SizedBox(width: compact ? 6 : 8),

                Tooltip(
                  message: canControlPlayback
                      ? 'Next track'
                      : 'Request next track',
                  child: IconButton(
                    onPressed: () async {
                      await onNext();
                    },
                    icon: const Icon(Icons.skip_next_rounded),
                    iconSize: compact ? 25 : 27,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(width: sideWidth),
        ],
      ),
    );
  }
}

// =====================================================================
// EMPTY PLAYER
// =====================================================================

class _EmptyPlayer extends StatelessWidget {
  const _EmptyPlayer();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: colorScheme.surfaceContainer,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.music_note_rounded,
                size: 48,
                color: colorScheme.onSurfaceVariant,
              ),

              const SizedBox(height: 8),

              Text(
                'Nothing playing',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
