import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../domain/models/room_queue_item.dart';
import 'room_panel_scroll_physics.dart';
import 'queue_item_tile.dart';

class DraggableQueue extends StatefulWidget {
  const DraggableQueue({
    super.key,
    required this.roomId,
    required this.items,
    required this.onRemove,
    required this.onReorder,
    this.allowContentScroll = true,
    this.onScrollHandoff,
  });

  final String roomId;
  final List<RoomQueueItem> items;

  final void Function(String itemId) onRemove;

  final Future<List<RoomQueueItem>> Function(String itemId, int newIndex)
  onReorder;

  final RoomPanelScrollHandoff? onScrollHandoff;
  final bool allowContentScroll;

  @override
  State<DraggableQueue> createState() => _DraggableQueueState();
}

class _DraggableQueueState extends State<DraggableQueue> {
  List<RoomQueueItem>? _optimisticItems;

  bool _saving = false;

  List<RoomQueueItem> get _visibleItems => _optimisticItems ?? widget.items;

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

    final reordered = List<RoomQueueItem>.from(current);

    final moved = reordered.removeAt(oldIndex);

    reordered.insert(targetIndex, moved);

    setState(() {
      _optimisticItems = reordered;
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
          SnackBar(content: Text('Failed to reorder queue: $error')),
        );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _optimisticItems = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _visibleItems;

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final feedbackWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth - 28
            : MediaQuery.sizeOf(context).width - 48;

        return ListView.separated(
          key: PageStorageKey<String>('queue-${widget.roomId}'),
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),

          physics: widget.allowContentScroll
              ? roomPanelScrollPhysics(
                  onHandoff: widget.onScrollHandoff,
                  allowContentScroll: true,
                )
              : const NeverScrollableScrollPhysics(),

          itemCount: items.length,

          separatorBuilder: (context, index) {
            return const SizedBox(height: 8);
          },

          itemBuilder: (context, index) {
            final item = items[index];

            final canDrag = !_saving && items.length > 1;

            return _QueueDropTarget(
              key: ValueKey(item.id),

              itemId: item.id,
              targetIndex: index,
              enabled: canDrag,

              onDrop: _dropOnIndex,

              child: QueueItemTile(
                item: item,
                number: index + 1,
                isNext: index == 0,
                canManage: true,

                dragHandle: canDrag
                    ? _QueueDragHandle(
                        itemId: item.id,
                        feedbackWidth: feedbackWidth,
                        feedback: QueueItemTile(
                          item: item,
                          number: index + 1,
                          isNext: index == 0,
                          canManage: false,
                          onRemove: () {},
                        ),
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

// DROP TARGET

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

class _QueueDragHandle extends StatelessWidget {
  const _QueueDragHandle({
    required this.itemId,
    required this.feedbackWidth,
    required this.feedback,
  });

  final String itemId;
  final double feedbackWidth;
  final Widget feedback;

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

    final handle = Tooltip(
      message: 'Drag to reorder',
      // A touch long-press tooltip wins the gesture arena before dragging
      // starts. Keep hover help, but let the handle own touch gestures.
      triggerMode: TooltipTriggerMode.manual,

      child: const SizedBox(
        width: 44,
        height: 48,
        child: Center(child: Icon(Icons.drag_indicator_rounded, size: 22)),
      ),
    );

    final dragFeedback = Material(
      type: MaterialType.transparency,

      child: Opacity(
        opacity: 0.94,

        child: SizedBox(width: feedbackWidth, child: feedback),
      ),
    );

    return Draggable<String>(
      data: itemId,

      axis: Axis.vertical,
      affinity: Axis.vertical,
      hitTestBehavior: HitTestBehavior.opaque,

      rootOverlay: true,

      maxSimultaneousDrags: 1,

      feedback: dragFeedback,

      // Anchor feedback to the full card instead of its handle.
      dragAnchorStrategy: (draggable, context, position) {
        RenderBox? card;
        context.visitAncestorElements((element) {
          if (element.widget is QueueItemTile) {
            card = element.findRenderObject() as RenderBox?;
            return false;
          }
          return true;
        });
        return card == null
            ? Offset(feedbackWidth / 2, 24)
            : position - card!.localToGlobal(Offset.zero);
      },
      feedbackOffset: Offset.zero,

      childWhenDragging: Opacity(opacity: 0.30, child: handle),

      child: isDesktop
          ? MouseRegion(cursor: SystemMouseCursors.grab, child: handle)
          : handle,
    );
  }
}

// READ-ONLY QUEUE

class ReadOnlyQueue extends StatelessWidget {
  const ReadOnlyQueue({
    required this.items,
    this.onScrollHandoff,
    required this.allowContentScroll,
    super.key,
  });

  final List<RoomQueueItem> items;

  final RoomPanelScrollHandoff? onScrollHandoff;

  final bool allowContentScroll;
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      physics: allowContentScroll
          ? roomPanelScrollPhysics(
              onHandoff: onScrollHandoff,
              allowContentScroll: true,
            )
          : const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];

        return QueueItemTile(
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
