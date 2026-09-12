import 'package:flutter/material.dart';
import '../../domain/models/room_queue_item.dart';
import 'queue_formatters.dart';

class ExpandedMobileQueueToolbar extends StatelessWidget {
  const ExpandedMobileQueueToolbar({
    super.key,
    required this.items,
    required this.canManage,
    required this.onAddTrack,
    required this.hasHistory,
    required this.showHistory,
    required this.onToggleHistory,
  });

  final List<RoomQueueItem> items;
  final bool canManage;
  final VoidCallback? onAddTrack;
  final bool hasHistory;
  final bool showHistory;
  final VoidCallback? onToggleHistory;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
        '${items.length} ${items.length == 1 ? 'track' : 'tracks'}';

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 38),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.queue_music_rounded,
                    size: 17,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      trackCountText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    '•',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 7),
                  Icon(
                    Icons.schedule_rounded,
                    size: 15,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      durationText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (canManage && onAddTrack != null) ...[
            const SizedBox(width: 8),
            _MobileQueueToolbarAction(
              tooltip: 'Add track',
              icon: Icons.add_rounded,
              onPressed: onAddTrack!,
            ),
          ],

          if (hasHistory && onToggleHistory != null) ...[
            const SizedBox(width: 8),
            _MobileQueueToolbarAction(
              tooltip: showHistory ? 'Back to queue' : 'Playback history',
              icon: showHistory
                  ? Icons.queue_music_rounded
                  : Icons.history_rounded,
              onPressed: onToggleHistory!,
            ),
          ],
        ],
      ),
    );
  }
}

class _MobileQueueToolbarAction extends StatelessWidget {
  const _MobileQueueToolbarAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 38, height: 38),
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
    );
  }
}
