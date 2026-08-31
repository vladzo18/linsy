import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:linsy/features/room/playback_history/application/room_playback_history_provider.dart';
import 'package:linsy/features/room/playback_history/domain/models/room_playback_history_item.dart';
import 'package:linsy/features/room/playback_history/presentation/room_playback_history_view.dart';

import '../../domain/models/playback_state.dart';
import '../../domain/models/room_queue_item.dart';
import '../controllers/playback_controller.dart';
import '../controllers/queue_controller.dart';
import '../controllers/room_state.dart';
import 'track_search_dialog.dart';

class RoomQueueSection extends ConsumerStatefulWidget {
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
  ConsumerState<RoomQueueSection> createState() => _RoomQueueSectionState();
}

class _RoomQueueSectionState extends ConsumerState<RoomQueueSection> {
  bool _showHistory = false;

  @override
  Widget build(BuildContext context) {
    if (widget.roomState.status != RoomStatus.ready ||
        widget.currentUserId == null) {
      return const SizedBox.shrink();
    }

    final currentMember = widget.roomState.members
        .where((member) => member.userId == widget.currentUserId)
        .firstOrNull;

    if (currentMember == null) {
      return const SizedBox.shrink();
    }

    final queueState = ref.watch(queueControllerProvider(widget.roomId));

    final playbackState = ref.watch(playbackControllerProvider(widget.roomId));

    final historyState = ref.watch(roomPlaybackHistoryProvider(widget.roomId));

    final historyItems =
        historyState.value ?? const <RoomPlaybackHistoryItem>[];

    final hasHistory = historyItems.isNotEmpty;

    final showHistory = _showHistory && hasHistory;

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
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Column(
            children: [
              // ===================================================
              // QUEUE STATUS
              //
              // ОСТАЁТСЯ ВСЕГДА.
              // History заменяет только список ниже.
              // ===================================================
              _QueueStatusHeader(
                playbackState: playbackState,
                items: items,
                canManage: canManage,
                onAddTrack: canManage ? () => _addTrack(context) : null,
                hasHistory: hasHistory,
                showHistory: showHistory,
                onToggleHistory: hasHistory
                    ? () {
                        setState(() {
                          _showHistory = !showHistory;
                        });
                      }
                    : null,
              ),

              const SizedBox(height: 14),

              if (showHistory) ...[
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Back to queue',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        setState(() {
                          _showHistory = false;
                        });
                      },
                      icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    ),

                    const SizedBox(width: 2),

                    const Icon(Icons.history_rounded, size: 18),

                    const SizedBox(width: 6),

                    Text(
                      'History',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                Divider(
                  height: 1,
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.55),
                ),

                const SizedBox(height: 10),
              ],
              // ===================================================
              // HISTORY
              // ===================================================
              if (showHistory)
                Expanded(
                  child: RoomPlaybackHistoryView(
                    items: historyItems,
                    canManage: canManage,
                    onAddToQueue: (item) {
                      return _addHistoryTrack(context, item);
                    },
                  ),
                )
              // ===================================================
              // EMPTY QUEUE
              // ===================================================
              else if (items.isEmpty)
                const Expanded(child: _EmptyQueue())
              // ===================================================
              // NORMAL QUEUE
              // ===================================================
              else
                Expanded(
                  child: canManage
                      ? _DraggableQueue(
                          roomId: widget.roomId,
                          items: items,
                          onRemove: (itemId) => _removeTrack(context, itemId),
                          onReorder: (itemId, newIndex) {
                            return ref
                                .read(
                                  queueControllerProvider(
                                    widget.roomId,
                                  ).notifier,
                                )
                                .reorderItem(
                                  itemId: itemId,
                                  newIndex: newIndex,
                                );
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

  Future<void> _addTrack(BuildContext context) async {
    final track = await showTrackSearchDialog(context);

    if (track == null) {
      return;
    }

    try {
      await ref
          .read(queueControllerProvider(widget.roomId).notifier)
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
  // ADD FROM HISTORY
  // ===================================================================

  Future<void> _addHistoryTrack(
    BuildContext context,
    RoomPlaybackHistoryItem item,
  ) async {
    try {
      await ref
          .read(queueControllerProvider(widget.roomId).notifier)
          .addItem(
            trackId: item.trackId,
            title: item.title,
            thumbnailUrl: item.thumbnailUrl,
            durationMs: item.durationMs,
            source: item.source,
          );

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            duration: Duration(milliseconds: 1200),
            content: Text('Added to queue.'),
          ),
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

  Future<void> _removeTrack(BuildContext context, String itemId) async {
    try {
      await ref
          .read(queueControllerProvider(widget.roomId).notifier)
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
// QUEUE STATUS HEADER
// =====================================================================

class _QueueStatusHeader extends StatelessWidget {
  const _QueueStatusHeader({
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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final playback = playbackState.value;

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
              ? '≥ ${_formatDuration(totalDurationMs)}'
              : 'Unknown'
        : _formatDuration(totalDurationMs);

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
          // =========================================================
          // PLAYBACK + ACTIONS
          // =========================================================
          Row(
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
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
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
                  ],
                ),
              ),

              // =====================================================
              // ADD TRACK
              // =====================================================
              if (canManage && onAddTrack != null) ...[
                const SizedBox(width: 12),

                FilledButton.tonalIcon(
                  onPressed: onAddTrack,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add track'),
                ),
              ],

              // =====================================================
              // HISTORY / BACK TO QUEUE
              // =====================================================
              if (hasHistory && onToggleHistory != null) ...[
                const SizedBox(width: 6),

                IconButton.filledTonal(
                  tooltip: showHistory ? 'Back to queue' : 'Playback history',

                  onPressed: onToggleHistory,

                  icon: Icon(
                    showHistory
                        ? Icons.queue_music_rounded
                        : Icons.history_rounded,
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 12),

          Divider(
            height: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),

          const SizedBox(height: 10),

          // =========================================================
          // QUEUE STATS
          // =========================================================
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

// =====================================================================
// CURRENT TRACK THUMBNAIL
// =====================================================================

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

// =====================================================================
// PLAYBACK STATUS
// =====================================================================

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
  // ===================================================
  // LOCAL DRAG SNAPSHOT
  // ===================================================
  //
  // Это НЕ второй source of truth.
  //
  // Он существует только пока пользователь
  // физически drag'ает item / ждёт завершения
  // начатого этим gesture reorder.
  //
  // После завершения всегда возвращаемся
  // к widget.items из QueueController.
  // ===================================================

  List<RoomQueueItem>? _dragItems;

  bool _saving = false;

  List<RoomQueueItem> get _visibleItems {
    return _dragItems ?? widget.items;
  }

  // ===================================================
  // DRAG START
  // ===================================================

  void _startDrag() {
    if (_saving || _dragItems != null) {
      return;
    }

    setState(() {
      _dragItems = List<RoomQueueItem>.from(widget.items);
    });
  }

  // ===================================================
  // DRAG END
  // ===================================================

  void _endDrag() {
    if (!mounted) {
      return;
    }

    if (_saving) {
      return;
    }

    setState(() {
      _dragItems = null;
    });
  }

  // ===================================================
  // DROP
  // ===================================================

  Future<void> _dropOnIndex(String itemId, int targetIndex) async {
    if (_saving) {
      return;
    }

    final current = List<RoomQueueItem>.from(_visibleItems);

    if (current.length < 2) {
      return;
    }

    final oldIndex = current.indexWhere((item) => item.id == itemId);

    if (oldIndex < 0 ||
        targetIndex < 0 ||
        targetIndex >= current.length ||
        oldIndex == targetIndex) {
      return;
    }

    // =================================================
    // VISUAL OPTIMISTIC REORDER
    // =================================================

    final reordered = List<RoomQueueItem>.from(current);

    final moved = reordered.removeAt(oldIndex);

    reordered.insert(targetIndex, moved);

    setState(() {
      _dragItems = reordered;

      _saving = true;
    });

    try {
      await widget.onReorder(itemId, targetIndex);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Failed to reorder queue: '
              '$error',
            ),
          ),
        );
    } finally {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;

        _dragItems = null;
      });
    }
  }

  // ===================================================
  // BUILD
  // ===================================================

  @override
  Widget build(BuildContext context) {
    final items = _visibleItems;

    if (items.isEmpty) {
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
          itemCount: items.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = items[index];

            final canDrag = !_saving && items.length > 1;

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
  const _EmptyQueue();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
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
              'Add a track to continue the queue.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
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
