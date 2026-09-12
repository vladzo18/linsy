import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:linsy/features/profile/application/profile_store.dart';

import '../../domain/models/playback_state.dart';
import '../../domain/models/room_queue_item.dart';
import 'queue_formatters.dart';
import 'room_panel_scroll_physics.dart';
import 'measured_content.dart';

class QueueCollapsedPreview extends ConsumerWidget {
  const QueueCollapsedPreview({
    required this.playbackState,
    required this.items,
    required this.showingHistory,
    required this.historyCount,
    required this.onExpand,
    this.onContentHeight,
    this.onAddTrack,
    this.onToggleHistory,
    super.key,
  });

  final AsyncValue<PlaybackState> playbackState;
  final List<RoomQueueItem> items;
  final bool showingHistory;
  final int historyCount;
  final VoidCallback onExpand;
  final ValueChanged<double>? onContentHeight;
  final VoidCallback? onAddTrack;
  final VoidCallback? onToggleHistory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final playback = playbackState.value;
    final hasTrack = playback?.trackId != null;
    final authorId = playback?.addedBy;
    final author = authorId == null
        ? null
        : ref.watch(profileByIdProvider(authorId));
    final authorName = author?.displayName?.trim();
    final title = hasTrack
        ? (playback!.title ?? playback.trackId!)
        : playbackState.isLoading
        ? 'Loading playback...'
        : playbackState.hasError
        ? 'Playback unavailable'
        : 'Nothing playing';
    final count = showingHistory ? historyCount : items.length;
    final duration = items.fold<int>(
      0,
      (sum, item) => sum + (item.durationMs ?? 0),
    );
    final summary =
        '${showingHistory ? 'Playback history' : 'Queue'} · $count ${count == 1 ? 'track' : 'tracks'}'
        '${!showingHistory && duration > 0 ? ' · ${items.any((item) => item.durationMs == null) ? '≥ ' : ''}${formatQueueDuration(duration)}' : ''}';

    // The summary keeps its natural height. Small windows can scroll it instead
    // of clipping metadata or squeezing text to an unreadable size.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: roomPanelScrollPhysics(
          allowContentScroll: true,
          onHandoff: (delta, metrics) {
            if (delta >= 0) return false;
            onExpand();
            return true;
          },
        ),
        padding: const EdgeInsets.all(12),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - 24).clamp(0.0, double.infinity),
          ),
          child: Align(
            alignment: Alignment.center,
            heightFactor: 1,
            child: MeasuredContent(
              onSize: (size) => onContentHeight?.call(size.height + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Material(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: onExpand,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: SizedBox.square(
                                        dimension: 44,
                                        child: playback?.thumbnailUrl != null
                                            ? Image.network(
                                                playback!.thumbnailUrl!,
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (
                                                      _,
                                                      error,
                                                      stack,
                                                    ) => const Icon(
                                                      Icons.music_note_rounded,
                                                    ),
                                              )
                                            : Icon(
                                                hasTrack && playback!.isPlaying
                                                    ? Icons.graphic_eq_rounded
                                                    : Icons.music_note_rounded,
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Flexible(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.titleMedium,
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            hasTrack
                                                ? '${playback!.isPlaying ? 'Playing' : 'Paused'} · Added by ${authorName == null || authorName.isEmpty ? 'Linsy user' : authorName}'
                                                : 'Add a track to start listening',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color:
                                                      colors.onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (onAddTrack != null || onToggleHistory != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 48,
                                  ),
                                  child: Center(
                                    child: onAddTrack == null
                                        ? const SizedBox(height: 48)
                                        : FilledButton.tonalIcon(
                                            onPressed: onAddTrack,
                                            icon: const Icon(Icons.add_rounded),
                                            label: const Text(
                                              'Add track',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                  ),
                                ),
                                if (onToggleHistory != null)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: IconButton(
                                      onPressed: onToggleHistory,
                                      tooltip: showingHistory
                                          ? 'Back to queue'
                                          : 'Playback history',
                                      icon: Icon(
                                        showingHistory
                                            ? Icons.queue_music_rounded
                                            : Icons.history_rounded,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        Divider(
                          height: 1,
                          indent: 12,
                          endIndent: 12,
                          color: colors.outlineVariant.withValues(alpha: 0.4),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Text(
                            summary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onExpand,
                    icon: const Icon(Icons.unfold_more_rounded, size: 18),
                    label: Text(showingHistory ? 'Open history' : 'Open queue'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
