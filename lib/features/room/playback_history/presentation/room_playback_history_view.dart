import 'package:flutter/material.dart';

import '../domain/models/room_playback_history_item.dart';

class RoomPlaybackHistoryView extends StatelessWidget {
  const RoomPlaybackHistoryView({
    required this.items,
    required this.canManage,
    required this.onAddToQueue,
    super.key,
  });

  final List<RoomPlaybackHistoryItem> items;

  final bool canManage;

  final Future<void> Function(RoomPlaybackHistoryItem item) onAddToQueue;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyHistory();
    }

    return ListView.separated(
      key: const PageStorageKey<String>('room-playback-history'),

      padding: const EdgeInsets.only(bottom: 12),

      physics: const ClampingScrollPhysics(),

      itemCount: items.length,

      separatorBuilder: (context, index) => const SizedBox(height: 8),

      itemBuilder: (context, index) {
        final item = items[index];

        return _HistoryItemTile(
          key: ValueKey(item.id),
          item: item,
          canManage: canManage,
          onAddToQueue: onAddToQueue,
        );
      },
    );
  }
}

// =====================================================================
// ITEM
// =====================================================================

class _HistoryItemTile extends StatefulWidget {
  const _HistoryItemTile({
    required this.item,
    required this.canManage,
    required this.onAddToQueue,
    super.key,
  });

  final RoomPlaybackHistoryItem item;

  final bool canManage;

  final Future<void> Function(RoomPlaybackHistoryItem item) onAddToQueue;

  @override
  State<_HistoryItemTile> createState() => _HistoryItemTileState();
}

class _HistoryItemTileState extends State<_HistoryItemTile> {
  bool _adding = false;

  Future<void> _add() async {
    if (_adding) {
      return;
    }

    setState(() {
      _adding = true;
    });

    try {
      await widget.onAddToQueue(widget.item);
    } finally {
      if (mounted) {
        setState(() {
          _adding = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final compact = MediaQuery.sizeOf(context).width < 600;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 7 : 9,
      ),

      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,

        borderRadius: BorderRadius.circular(14),

        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.60),
        ),
      ),

      child: Row(
        children: [
          // ===========================================================
          // THUMBNAIL
          // ===========================================================
          _HistoryThumbnail(url: widget.item.thumbnailUrl, compact: compact),

          SizedBox(width: compact ? 8 : 12),

          // ===========================================================
          // INFO
          // ===========================================================
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  widget.item.title ?? widget.item.trackId,

                  maxLines: 1,

                  overflow: TextOverflow.ellipsis,

                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 3),

                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _sourceLabel(widget.item.source),

                        maxLines: 1,

                        overflow: TextOverflow.ellipsis,

                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),

                    if (widget.item.durationMs != null) ...[
                      Text(
                        '  •  ',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),

                      Text(
                        _formatDuration(widget.item.durationMs!),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],

                    Text(
                      '  (Last played at: ',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),

                    Text(
                      '${_formatPlayedAt(widget.item.playedAt)})',

                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ===========================================================
          // ADD AGAIN
          // ===========================================================
          if (widget.canManage) ...[
            const SizedBox(width: 4),

            IconButton(
              tooltip: 'Add to queue',

              onPressed: _adding ? null : _add,

              icon: _adding
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_to_queue_rounded),
            ),
          ],
        ],
      ),
    );
  }
}

// =====================================================================
// THUMBNAIL
// =====================================================================

class _HistoryThumbnail extends StatelessWidget {
  const _HistoryThumbnail({required this.url, required this.compact});

  final String? url;

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final width = compact ? 58.0 : 80.0;

    final height = width * 9 / 16;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),

      child: SizedBox(
        width: width,
        height: height,

        child: url == null || url!.isEmpty
            ? const ColoredBox(
                color: Colors.black12,
                child: Icon(Icons.music_note_rounded),
              )
            : Image.network(
                url!,
                fit: BoxFit.cover,

                errorBuilder: (context, error, stackTrace) {
                  return const ColoredBox(
                    color: Colors.black12,
                    child: Icon(Icons.music_note_rounded),
                  );
                },
              ),
      ),
    );
  }
}

// =====================================================================
// EMPTY
// =====================================================================

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),

        child: Column(
          mainAxisSize: MainAxisSize.min,

          children: [
            Icon(
              Icons.history_rounded,

              size: 42,

              color: colorScheme.onSurfaceVariant,
            ),

            const SizedBox(height: 10),

            Text(
              'Nothing played yet',

              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// HELPERS
// =====================================================================

String _sourceLabel(String source) {
  switch (source) {
    case 'youtube':
      return 'YouTube';

    default:
      if (source.isEmpty) {
        return 'Unknown source';
      }

      return source[0].toUpperCase() + source.substring(1);
  }
}

String _formatDuration(int milliseconds) {
  final totalSeconds = milliseconds ~/ 1000;

  final hours = totalSeconds ~/ 3600;

  final minutes = (totalSeconds % 3600) ~/ 60;

  final seconds = totalSeconds % 60;

  if (hours > 0) {
    return '$hours:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  return '$minutes:'
      '${seconds.toString().padLeft(2, '0')}';
}

String _formatPlayedAt(DateTime playedAt) {
  final local = playedAt.toLocal();

  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}
