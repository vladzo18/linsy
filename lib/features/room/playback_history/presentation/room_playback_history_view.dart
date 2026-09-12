import 'package:flutter/material.dart';
import '../../presentation/widgets/room_panel_scroll_physics.dart';

import '../domain/models/room_playback_history_item.dart';

import 'history_item_tile.dart';

class RoomPlaybackHistoryView extends StatelessWidget {
  const RoomPlaybackHistoryView({
    required this.items,
    required this.canManage,
    required this.onAddToQueue,
    this.allowContentScroll = true,
    this.onScrollHandoff,
    super.key,
  });

  final List<RoomPlaybackHistoryItem> items;

  final bool canManage;
  final bool allowContentScroll;
  final RoomPanelScrollHandoff? onScrollHandoff;

  final Future<void> Function(RoomPlaybackHistoryItem item) onAddToQueue;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyHistory();
    }

    return ListView.separated(
      key: const PageStorageKey<String>('room-playback-history'),

      padding: const EdgeInsets.only(bottom: 12),

      physics: roomPanelScrollPhysics(
        onHandoff: onScrollHandoff,
        allowContentScroll: allowContentScroll,
      ),

      itemCount: items.length,

      separatorBuilder: (context, index) => const SizedBox(height: 8),

      itemBuilder: (context, index) {
        final item = items[index];

        return HistoryItemTile(
          key: ValueKey(item.id),
          item: item,
          canManage: canManage,
          onAddToQueue: onAddToQueue,
        );
      },
    );
  }
}

// ITEM

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
