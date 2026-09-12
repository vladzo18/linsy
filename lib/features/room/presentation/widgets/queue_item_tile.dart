import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:linsy/features/profile/application/profile_store.dart';
import '../../domain/models/room_queue_item.dart';
import 'queue_formatters.dart';

class QueueItemTile extends ConsumerWidget {
  const QueueItemTile({
    super.key,
    required this.item,
    required this.number,
    required this.isNext,
    required this.canManage,
    required this.onRemove,
    this.dragHandle,
  });

  final RoomQueueItem item;

  final int number;
  final bool isNext;
  final bool canManage;

  final VoidCallback onRemove;

  final Widget? dragHandle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    final compact = MediaQuery.sizeOf(context).width < 600;

    final addedByProfile = ref.watch(profileByIdProvider(item.addedBy));

    final addedByName = addedByProfile?.displayName?.trim();

    final addedByLabel = addedByName != null && addedByName.isNotEmpty
        ? addedByName
        : 'Linsy user';

    final tile = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 7 : 9,
      ),
      decoration: BoxDecoration(
        color: isNext
            ? colorScheme.primaryContainer.withValues(alpha: 0.30)
            : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isNext ? 0 : 14),
          topRight: const Radius.circular(14),
          bottomLeft: const Radius.circular(14),
          bottomRight: const Radius.circular(14),
        ),
        border: Border.all(
          width: isNext ? 1.5 : 1,
          color: isNext
              ? colorScheme.primary
              : colorScheme.outlineVariant.withValues(alpha: 0.60),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // NUMBER
          SizedBox(
            width: compact ? 20 : 28,
            child: Text(
              '$number',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          SizedBox(width: compact ? 5 : 8),

          // THUMBNAIL
          _QueueThumbnail(url: item.thumbnailUrl, compact: compact),

          SizedBox(width: compact ? 8 : 12),

          // INFO
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title ?? item.trackId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 3),

                Text(
                  '${_sourceLabel(item.source)}'
                  '${item.durationMs == null ? '' : '  •  ${formatQueueDuration(item.durationMs!)}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 3),

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
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ACTIONS
          if (canManage) ...[
            SizedBox(width: compact ? 1 : 4),

            ?dragHandle,

            IconButton(
              tooltip: 'Remove from queue',
              visualDensity: VisualDensity.compact,
              constraints: compact
                  ? const BoxConstraints(minWidth: 34, minHeight: 34)
                  : null,
              padding: compact ? const EdgeInsets.all(5) : null,
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded),
              iconSize: compact ? 21 : 24,
            ),
          ],
        ],
      ),
    );
    if (!isNext) return tile;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [const _NextBadge(), tile],
    );
  }
}

// NEXT

class _NextBadge extends StatelessWidget {
  const _NextBadge();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
        border: Border(
          top: BorderSide(color: colorScheme.primary, width: 1.5),
          left: BorderSide(color: colorScheme.primary, width: 1.5),
          right: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),
      child: Text(
        'NEXT',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onPrimaryContainer,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
      ),
    );
  }
}

// THUMBNAIL

class _QueueThumbnail extends StatelessWidget {
  const _QueueThumbnail({required this.url, required this.compact});

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
