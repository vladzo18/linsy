import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:linsy/features/profile/application/profile_store.dart';
import '../../domain/models/playback_state.dart';
import '../../domain/models/room_queue_item.dart';
import 'queue_formatters.dart';

class QueueStatusHeader extends ConsumerWidget {
  const QueueStatusHeader({
    super.key,
    required this.playbackState,
    required this.items,
    required this.canManage,
    required this.onAddTrack,
    required this.hasHistory,
    required this.showHistory,
    required this.onToggleHistory,
  });

  final AsyncValue<PlaybackState> playbackState;

  final List<RoomQueueItem> items;

  final bool canManage;

  final VoidCallback? onAddTrack;

  final bool hasHistory;

  final bool showHistory;

  final VoidCallback? onToggleHistory;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    final playback = playbackState.value;

    final addedByUserId = playback?.addedBy;

    final addedByProfile = addedByUserId == null
        ? null
        : ref.watch(profileByIdProvider(addedByUserId));

    final addedByName = addedByProfile?.displayName?.trim();

    final addedByLabel = addedByName != null && addedByName.isNotEmpty
        ? addedByName
        : 'Linsy user';

    final playbackLoading = playbackState.isLoading && playback == null;

    final playbackUnavailable = playbackState.hasError && playback == null;

    final hasTrack = playback != null && playback.trackId != null;

    final totalDurationMs = items.fold<int>(
      0,
      (total, item) => total + (item.durationMs ?? 0),
    );

    final hasUnknownDuration = items.any((item) => item.durationMs == null);

    final durationText = hasUnknownDuration
        ? totalDurationMs > 0
              ? '≥ ${formatQueueDuration(totalDurationMs)}'
              : 'Unknown'
        : formatQueueDuration(totalDurationMs);

    final trackCountText =
        '${items.length} '
        '${items.length == 1 ? 'track' : 'tracks'}';

    String title;

    if (playbackLoading) {
      title = 'Loading playback...';
    } else if (playbackUnavailable) {
      title = 'Playback unavailable';
    } else if (!hasTrack) {
      title = 'Nothing playing';
    } else {
      final playbackTitle = playback.title?.trim();

      title = playbackTitle != null && playbackTitle.isNotEmpty
          ? playbackTitle
          : playback.trackId!;
    }

    final thumbnailUrl = hasTrack ? playback.thumbnailUrl : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.60),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // PLAYBACK + ACTIONS
          LayoutBuilder(
            builder: (context, constraints) {
              final trackInfo = Row(
                children: [
                  _CurrentTrackThumbnail(
                    url: thumbnailUrl,
                    loading: playbackLoading,
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),

                        const SizedBox(height: 6),

                        if (playbackLoading)
                          const _PlaybackStatusBadge.loading()
                        else if (playbackUnavailable)
                          const _PlaybackStatusBadge.unavailable()
                        else if (!hasTrack)
                          const _PlaybackStatusBadge.idle()
                        else
                          _PlaybackStatusBadge(isPlaying: playback.isPlaying),

                        if (hasTrack && addedByUserId != null) ...[
                          const SizedBox(height: 5),

                          Row(
                            children: [
                              Icon(
                                Icons.person_outline_rounded,
                                size: 13,
                                color: colorScheme.onSurfaceVariant,
                              ),

                              const SizedBox(width: 4),

                              Flexible(
                                child: Text(
                                  'Added by $addedByLabel',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
              final actions = Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: constraints.maxWidth < 520
                    ? WrapAlignment.center
                    : WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // ADD TRACK
                  if (canManage && onAddTrack != null) ...[
                    FilledButton.tonalIcon(
                      onPressed: onAddTrack!,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add track'),
                    ),
                  ],

                  // HISTORY / BACK TO QUEUE
                  if (hasHistory && onToggleHistory != null) ...[
                    IconButton.filledTonal(
                      tooltip: showHistory
                          ? 'Back to queue'
                          : 'Playback history',

                      onPressed: onToggleHistory!,

                      icon: Icon(
                        showHistory
                            ? Icons.queue_music_rounded
                            : Icons.history_rounded,
                      ),
                    ),
                  ],
                ],
              );
              if (constraints.maxWidth < 520) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    trackInfo,
                    if ((canManage && onAddTrack != null) ||
                        (hasHistory && onToggleHistory != null)) ...[
                      const SizedBox(height: 10),
                      actions,
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: trackInfo),
                  const SizedBox(width: 12),
                  actions,
                ],
              );
            },
          ),
          const SizedBox(height: 12),

          Divider(
            height: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),

          const SizedBox(height: 10),

          // QUEUE STATS
          Wrap(
            spacing: 7,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(
                Icons.queue_music_rounded,
                size: 17,
                color: colorScheme.onSurfaceVariant,
              ),

              Text(
                trackCountText,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),

              Text('•', style: TextStyle(color: colorScheme.onSurfaceVariant)),

              Icon(
                Icons.schedule_rounded,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),

              Text(
                'Queue duration $durationText',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// CURRENT TRACK THUMBNAIL

class _CurrentTrackThumbnail extends StatelessWidget {
  const _CurrentTrackThumbnail({required this.url, required this.loading});

  final String? url;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: SizedBox(
        width: 64,
        height: 36,
        child: loading
            ? ColoredBox(
                color: colorScheme.surfaceContainerHighest,
                child: const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            : url == null || url!.isEmpty
            ? ColoredBox(
                color: colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.music_note_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return ColoredBox(
                    color: colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.music_note_rounded,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  );
                },
              ),
      ),
    );
  }
}

// PLAYBACK STATUS

class _PlaybackStatusBadge extends StatelessWidget {
  const _PlaybackStatusBadge({required bool isPlaying})
    : _state = isPlaying
          ? _PlaybackVisualState.playing
          : _PlaybackVisualState.paused;

  const _PlaybackStatusBadge.loading() : _state = _PlaybackVisualState.loading;

  const _PlaybackStatusBadge.unavailable()
    : _state = _PlaybackVisualState.unavailable;

  const _PlaybackStatusBadge.idle() : _state = _PlaybackVisualState.idle;

  final _PlaybackVisualState _state;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final IconData icon;
    final String label;

    switch (_state) {
      case _PlaybackVisualState.playing:
        icon = Icons.play_arrow_rounded;
        label = 'Playing';

      case _PlaybackVisualState.paused:
        icon = Icons.pause_rounded;
        label = 'Paused';

      case _PlaybackVisualState.idle:
        icon = Icons.stop_rounded;
        label = 'Idle';

      case _PlaybackVisualState.loading:
        icon = Icons.sync_rounded;
        label = 'Loading';

      case _PlaybackVisualState.unavailable:
        icon = Icons.cloud_off_outlined;
        label = 'Unavailable';
    }

    final highlighted = _state == _PlaybackVisualState.playing;

    final backgroundColor = highlighted
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;

    final foregroundColor = highlighted
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: foregroundColor),

            const SizedBox(width: 3),

            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _PlaybackVisualState { playing, paused, idle, loading, unavailable }
