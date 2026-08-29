import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/room_queue_item.dart';
import '../controllers/queue_controller.dart';
import '../controllers/room_state.dart';
import 'track_search_dialog.dart';

class RoomQueueSection extends ConsumerWidget {
  const RoomQueueSection({
    required this.roomId,
    required this.roomState,
    required this.currentUserId,
    super.key,
  });

  final String roomId;
  final RoomState roomState;
  final String? currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (roomState.status != RoomStatus.ready || currentUserId == null) {
      return const SizedBox.shrink();
    }

    final currentMember = roomState.members
        .where((member) => member.user.id == currentUserId)
        .firstOrNull;

    if (currentMember == null) {
      return const SizedBox.shrink();
    }

    final queueState = ref.watch(queueControllerProvider(roomId));

    final canManage = currentMember.canControlPlayback;

    return queueState.when(
      // ===========================================================
      // LOADING
      // ===========================================================
      loading: () => const Center(child: CircularProgressIndicator()),

      // ===========================================================
      // ERROR
      // ===========================================================
      error: (error, stackTrace) => _QueueError(error: error),

      // ===========================================================
      // DATA
      // ===========================================================
      data: (items) {
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: _EmptyQueue(
              canManage: canManage,
              onAddTrack: canManage ? () => _addTrack(context, ref) : null,
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Column(
            children: [
              // ===================================================
              // ADD TRACK
              // ===================================================
              if (canManage) ...[
                Center(
                  child: FilledButton.tonalIcon(
                    onPressed: () => _addTrack(context, ref),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add track'),
                  ),
                ),

                const SizedBox(height: 14),
              ],

              // ===================================================
              // QUEUE
              // ===================================================
              Expanded(
                child: canManage
                    ? _DraggableQueue(
                        roomId: roomId,
                        items: items,
                        onRemove: (itemId) =>
                            _removeTrack(context, ref, itemId),
                        onReorder: (itemId, newIndex) {
                          return ref
                              .read(queueControllerProvider(roomId).notifier)
                              .reorderItem(itemId: itemId, newIndex: newIndex);
                        },
                      )
                    : _ReadOnlyQueue(items: items),
              ),
            ],
          ),
        );
      },
    );
  }

  // ===================================================================
  // ADD
  // ===================================================================

  Future<void> _addTrack(BuildContext context, WidgetRef ref) async {
    final track = await showTrackSearchDialog(context);

    if (track == null) {
      return;
    }

    try {
      await ref
          .read(queueControllerProvider(roomId).notifier)
          .addItem(
            trackId: track.trackId,
            title: track.title,
            thumbnailUrl: track.thumbnailUrl,
            durationMs: track.durationMs,
            source: track.source,
          );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Failed to add track: $error')));
    }
  }

  // ===================================================================
  // REMOVE
  // ===================================================================

  Future<void> _removeTrack(
    BuildContext context,
    WidgetRef ref,
    String itemId,
  ) async {
    try {
      await ref
          .read(queueControllerProvider(roomId).notifier)
          .removeItem(itemId);
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Failed to remove track: $error')),
        );
    }
  }
}

// =====================================================================
// DRAGGABLE QUEUE
// =====================================================================

class _DraggableQueue extends StatefulWidget {
  const _DraggableQueue({
    required this.roomId,
    required this.items,
    required this.onRemove,
    required this.onReorder,
  });

  final String roomId;
  final List<RoomQueueItem> items;

  final void Function(String itemId) onRemove;

  final Future<List<RoomQueueItem>> Function(String itemId, int newIndex)
  onReorder;

  @override
  State<_DraggableQueue> createState() => _DraggableQueueState();
}

class _DraggableQueueState extends State<_DraggableQueue> {
  late List<RoomQueueItem> _items;

  bool _dragging = false;
  bool _saving = false;

  List<RoomQueueItem>? _pendingExternalItems;

  @override
  void initState() {
    super.initState();

    _items = List<RoomQueueItem>.from(widget.items);
  }

  // ===================================================================
  // EXTERNAL UPDATE
  // ===================================================================

  @override
  void didUpdateWidget(covariant _DraggableQueue oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Родитель мог rebuild-нуться вообще без
    // изменения Queue. Такой rebuild нам не интересен.
    if (_sameQueue(oldWidget.items, widget.items)) {
      return;
    }

    final incoming = List<RoomQueueItem>.from(widget.items);

    // Во время drag / RPC не даём realtime
    // менять локальный список под курсором.
    if (_dragging || _saving) {
      _pendingExternalItems = incoming;

      return;
    }

    _items = incoming;
  }

  // ===================================================================
  // DRAG START
  // ===================================================================

  void _startDrag() {
    if (_saving || _dragging) {
      return;
    }

    setState(() {
      _dragging = true;
    });
  }

  // ===================================================================
  // DRAG END
  // ===================================================================

  void _endDrag() {
    if (!mounted) {
      return;
    }

    setState(() {
      _dragging = false;

      // Drop уже произошёл и RPC ещё идёт.
      // Пока ничего извне не применяем.
      if (_saving) {
        return;
      }

      final pending = _pendingExternalItems;

      if (pending != null) {
        _items = List<RoomQueueItem>.from(pending);

        _pendingExternalItems = null;
      }
    });
  }

  // ===================================================================
  // DROP
  // ===================================================================

  Future<void> _dropOnIndex(String itemId, int targetIndex) async {
    if (_saving || _items.length < 2) {
      return;
    }

    final oldIndex = _items.indexWhere((item) => item.id == itemId);

    if (oldIndex < 0 ||
        targetIndex < 0 ||
        targetIndex >= _items.length ||
        oldIndex == targetIndex) {
      return;
    }

    final previous = List<RoomQueueItem>.from(_items);

    final reordered = List<RoomQueueItem>.from(_items);

    final moved = reordered.removeAt(oldIndex);

    // targetIndex здесь уже является
    // финальным индексом.
    reordered.insert(targetIndex, moved);

    setState(() {
      _items = reordered;
      _saving = true;
    });

    try {
      final serverItems = await widget.onReorder(itemId, targetIndex);

      if (!mounted) {
        return;
      }

      final pending = _pendingExternalItems;

      setState(() {
        // Если realtime уже принёс более свежее
        // состояние — используем его.
        _items = pending != null
            ? List<RoomQueueItem>.from(pending)
            : List<RoomQueueItem>.from(serverItems);

        _pendingExternalItems = null;

        _saving = false;
        _dragging = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      final pending = _pendingExternalItems;

      setState(() {
        _items = pending != null ? List<RoomQueueItem>.from(pending) : previous;

        _pendingExternalItems = null;

        _saving = false;
        _dragging = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Failed to reorder queue: $error')),
        );
    }
  }

  // ===================================================================
  // BUILD
  // ===================================================================

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final feedbackWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 48;

        return ListView.separated(
          key: PageStorageKey<String>('queue-${widget.roomId}'),
          padding: const EdgeInsets.only(bottom: 12),
          physics: const ClampingScrollPhysics(),
          itemCount: _items.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = _items[index];

            final canDrag = !_saving && _items.length > 1;

            return _QueueDropTarget(
              key: ValueKey(item.id),
              itemId: item.id,
              targetIndex: index,
              enabled: canDrag,
              onDrop: _dropOnIndex,
              child: _QueueItemTile(
                item: item,
                number: index + 1,
                isNext: index == 0,
                canManage: true,

                dragHandle: canDrag
                    ? _QueueDragHandle(
                        itemId: item.id,
                        feedbackWidth: feedbackWidth,
                        feedback: _QueueItemTile(
                          item: item,
                          number: index + 1,
                          isNext: index == 0,
                          canManage: false,
                          onRemove: () {},
                        ),
                        onDragStarted: _startDrag,
                        onDragEnded: _endDrag,
                      )
                    : null,

                onRemove: () {
                  if (_saving) {
                    return;
                  }

                  widget.onRemove(item.id);
                },
              ),
            );
          },
        );
      },
    );
  }
}

// =====================================================================
// DROP TARGET
// =====================================================================

class _QueueDropTarget extends StatelessWidget {
  const _QueueDropTarget({
    super.key,
    required this.itemId,
    required this.targetIndex,
    required this.enabled,
    required this.onDrop,
    required this.child,
  });

  final String itemId;
  final int targetIndex;
  final bool enabled;

  final Future<void> Function(String itemId, int targetIndex) onDrop;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        return enabled && details.data != itemId;
      },

      onAcceptWithDetails: (details) {
        unawaited(onDrop(details.data, targetIndex));
      },

      builder: (context, candidateData, rejectedData) {
        final hovering =
            enabled &&
            candidateData.any((data) => data != null && data != itemId);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: hovering
                ? [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.22),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: child,
        );
      },
    );
  }
}

// =====================================================================
// READ-ONLY QUEUE
// =====================================================================

class _ReadOnlyQueue extends StatelessWidget {
  const _ReadOnlyQueue({required this.items});

  final List<RoomQueueItem> items;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 12),
      physics: const ClampingScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];

        return _QueueItemTile(
          key: ValueKey(item.id),
          item: item,
          number: index + 1,
          isNext: index == 0,
          canManage: false,
          onRemove: () {},
        );
      },
    );
  }
}

// =====================================================================
// DRAG HANDLE
// =====================================================================

class _QueueDragHandle extends StatelessWidget {
  const _QueueDragHandle({
    required this.itemId,
    required this.feedbackWidth,
    required this.feedback,
    required this.onDragStarted,
    required this.onDragEnded,
  });

  final String itemId;
  final double feedbackWidth;

  final Widget feedback;

  final VoidCallback onDragStarted;
  final VoidCallback onDragEnded;

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

    final handle = Tooltip(
      message: isDesktop ? 'Drag to reorder' : 'Hold and drag to reorder',
      child: const Padding(
        padding: EdgeInsets.all(6),
        child: Icon(Icons.drag_indicator_rounded, size: 22),
      ),
    );

    final dragFeedback = Material(
      color: Colors.transparent,
      child: Opacity(
        opacity: 0.94,
        child: SizedBox(width: feedbackWidth, child: feedback),
      ),
    );

    if (isDesktop) {
      return Draggable<String>(
        data: itemId,

        maxSimultaneousDrags: 1,

        feedback: dragFeedback,

        feedbackOffset: const Offset(-20, -20),

        childWhenDragging: Opacity(opacity: 0.30, child: handle),

        onDragStarted: onDragStarted,

        onDragEnd: (_) {
          onDragEnded();
        },

        child: MouseRegion(cursor: SystemMouseCursors.grab, child: handle),
      );
    }

    return LongPressDraggable<String>(
      data: itemId,

      maxSimultaneousDrags: 1,

      feedback: dragFeedback,

      childWhenDragging: Opacity(opacity: 0.30, child: handle),

      onDragStarted: onDragStarted,

      onDragEnd: (_) {
        onDragEnded();
      },

      child: handle,
    );
  }
}

// =====================================================================
// QUEUE ITEM
// =====================================================================

class _QueueItemTile extends StatelessWidget {
  const _QueueItemTile({
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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final compact = MediaQuery.sizeOf(context).width < 600;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 7 : 9,
      ),
      decoration: BoxDecoration(
        color: isNext
            ? colorScheme.primaryContainer.withValues(alpha: 0.30)
            : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isNext
              ? colorScheme.primary.withValues(alpha: 0.25)
              : colorScheme.outlineVariant.withValues(alpha: 0.60),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // =======================================================
          // NUMBER
          // =======================================================
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

          // =======================================================
          // THUMBNAIL
          // =======================================================
          _QueueThumbnail(url: item.thumbnailUrl, compact: compact),

          SizedBox(width: compact ? 8 : 12),

          // =======================================================
          // INFO
          // =======================================================
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

                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _sourceLabel(item.source),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),

                    if (item.durationMs != null) ...[
                      Text(
                        '  •  ',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),

                      Text(
                        _formatDuration(item.durationMs!),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // =======================================================
          // NEXT
          // =======================================================
          if (isNext) ...[SizedBox(width: compact ? 5 : 8), const _NextBadge()],

          // =======================================================
          // ACTIONS
          // =======================================================
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
  }
}

// =====================================================================
// NEXT
// =====================================================================

class _NextBadge extends StatelessWidget {
  const _NextBadge();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'NEXT',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onPrimary,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
      ),
    );
  }
}

// =====================================================================
// THUMBNAIL
// =====================================================================

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

// =====================================================================
// EMPTY
// =====================================================================

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue({required this.canManage, required this.onAddTrack});

  final bool canManage;
  final VoidCallback? onAddTrack;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.queue_music_rounded,
              size: 42,
              color: colorScheme.onSurfaceVariant,
            ),

            const SizedBox(height: 10),

            Text(
              'Queue is empty',
              style: Theme.of(context).textTheme.titleMedium,
            ),

            const SizedBox(height: 4),

            Text(
              canManage
                  ? 'Add something to play next.'
                  : 'Tracks added by the host or moderators will appear here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),

            if (canManage && onAddTrack != null) ...[
              const SizedBox(height: 14),

              FilledButton.tonalIcon(
                onPressed: onAddTrack,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add track'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// ERROR
// =====================================================================

class _QueueError extends StatelessWidget {
  const _QueueError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),

            const SizedBox(height: 8),

            Text(
              'Failed to load queue.',
              style: Theme.of(context).textTheme.titleSmall,
            ),

            const SizedBox(height: 4),

            Text(
              '$error',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
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

bool _sameQueue(List<RoomQueueItem> a, List<RoomQueueItem> b) {
  if (a.length != b.length) {
    return false;
  }

  for (var index = 0; index < a.length; index++) {
    if (a[index].id != b[index].id || a[index].position != b[index].position) {
      return false;
    }
  }

  return true;
}

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
