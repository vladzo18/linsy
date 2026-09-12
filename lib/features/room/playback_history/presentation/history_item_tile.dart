import 'package:flutter/material.dart';

import '../domain/models/room_playback_history_item.dart';

class HistoryItemTile extends StatefulWidget {
  const HistoryItemTile({
    required this.item,
    required this.canManage,
    required this.onAddToQueue,
    super.key,
  });

  final RoomPlaybackHistoryItem item;

  final bool canManage;

  final Future<void> Function(RoomPlaybackHistoryItem item) onAddToQueue;

  @override
  State<HistoryItemTile> createState() => _HistoryItemTileState();
}

class _HistoryItemTileState extends State<HistoryItemTile> {
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
          // THUMBNAIL
          _HistoryThumbnail(url: widget.item.thumbnailUrl, compact: compact),

          SizedBox(width: compact ? 8 : 12),

          // INFO
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

                Text(
                  '${_sourceLabel(widget.item.source)}'
                  '${widget.item.durationMs == null ? "" : " · ${_formatDuration(widget.item.durationMs!)}"}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Last played: ${_formatPlayedAt(widget.item.playedAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // ADD AGAIN
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

// THUMBNAIL

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

// EMPTY

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
