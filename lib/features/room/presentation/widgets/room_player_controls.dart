import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../library/application/saved_tracks_controller.dart';
import '../../domain/models/playback_state.dart';
import 'player_volume_control.dart';

class StartQueueControls extends StatelessWidget {
  const StartQueueControls({
    super.key,
    required this.compact,
    required this.onStart,
  });

  final bool compact;

  final Future<void> Function() onStart;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 44 : 50,
      child: Row(
        children: [
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

// CONTROLS ROW

class PlayerControlsRow extends StatelessWidget {
  const PlayerControlsRow({
    super.key,
    required this.playback,
    required this.isPlaying,
    required this.canControlPlayback,
    required this.compact,
    required this.onPlayPause,
    required this.onNext,
  });

  final PlaybackState playback;

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
          SizedBox(
            width: sideWidth,
            child: const Align(
              alignment: Alignment.centerLeft,
              child: PlayerVolumeControl(),
            ),
          ),

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

          SizedBox(
            width: sideWidth,
            child: Align(
              alignment: Alignment.centerRight,
              child: _SaveTrackButton(playback: playback, compact: compact),
            ),
          ),
        ],
      ),
    );
  }
}

// SAVE TRACK

class _SaveTrackButton extends ConsumerStatefulWidget {
  const _SaveTrackButton({required this.playback, required this.compact});

  final PlaybackState playback;

  final bool compact;

  @override
  ConsumerState<_SaveTrackButton> createState() => _SaveTrackButtonState();
}

class _SaveTrackButtonState extends ConsumerState<_SaveTrackButton> {
  bool _changing = false;

  Future<void> _toggleSaved() async {
    if (_changing) {
      return;
    }

    final trackId = widget.playback.trackId?.trim();

    final source = widget.playback.source?.trim();

    if (trackId == null ||
        trackId.isEmpty ||
        source == null ||
        source.isEmpty) {
      return;
    }

    final controller = ref.read(savedTracksControllerProvider.notifier);

    final isSaved = controller.isSaved(source: source, trackId: trackId);

    setState(() {
      _changing = true;
    });

    try {
      if (isSaved) {
        await controller.removeTrack(source: source, trackId: trackId);
      } else {
        final title = widget.playback.title?.trim();

        await controller.saveTrack(
          source: source,
          trackId: trackId,
          title: title == null || title.isEmpty ? trackId : title,
          channelTitle: '',
          thumbnailUrl: widget.playback.thumbnailUrl,
          durationMs: widget.playback.durationMs,
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Failed to update saved tracks: $error')),
        );
    } finally {
      if (mounted) {
        setState(() {
          _changing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final savedState = ref.watch(savedTracksControllerProvider);

    final trackId = widget.playback.trackId?.trim();

    final source = widget.playback.source?.trim();

    final validTrack =
        trackId != null &&
        trackId.isNotEmpty &&
        source != null &&
        source.isNotEmpty;

    final savedTracks = savedState.value;

    final isSaved =
        validTrack &&
        savedTracks != null &&
        savedTracks.any(
          (track) => track.source == source && track.trackId == trackId,
        );

    return IconButton(
      tooltip: isSaved ? 'Remove from saved' : 'Save track',
      onPressed: validTrack && !_changing ? _toggleSaved : null,
      icon: Icon(
        isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      ),
      iconSize: widget.compact ? 23 : 25,
    );
  }
}

// EMPTY PLAYER

class EmptyPlayer extends StatelessWidget {
  const EmptyPlayer({super.key});

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
