import 'package:linsy/core/feedback/app_dialog.dart';
import '../../domain/models/room_action_request.dart';
import 'confirm_room_request.dart';
import 'package:linsy/core/feedback/app_notice.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../playback_history/application/room_playback_history_provider.dart';
import '../../playback_history/domain/models/room_playback_history_item.dart';
import '../../playback_history/presentation/room_playback_history_view.dart';
import 'room_panel_scroll_physics.dart';
import '../controllers/playback_controller.dart';
import '../controllers/queue_controller.dart';
import '../controllers/room_state.dart';
import 'track_search_dialog.dart';
import 'queue_toolbar.dart';
import 'queue_status_header.dart';
import 'queue_list.dart';
import 'queue_collapsed_preview.dart';

class RoomQueueSection extends ConsumerStatefulWidget {
  const RoomQueueSection({
    required this.roomId,
    required this.roomState,
    required this.currentUserId,
    this.onScrollHandoff,
    this.allowContentScroll = true,
    this.isPanelExpanded = false,
    this.onExpand,
    this.onQueueContentHeight,
    super.key,
  });

  final String roomId;
  final RoomState roomState;
  final String? currentUserId;
  final RoomPanelScrollHandoff? onScrollHandoff;
  final bool allowContentScroll;

  /// Visual state of the mobile room panel.
  ///
  /// Kept separate from scroll physics on purpose.
  final bool isPanelExpanded;
  final VoidCallback? onExpand;
  final ValueChanged<double>? onQueueContentHeight;

  @override
  ConsumerState<RoomQueueSection> createState() => _RoomQueueSectionState();
}

class _RoomQueueSectionState extends ConsumerState<RoomQueueSection> {
  bool _showHistory = false;
  bool _confirmingRemoval = false;
  bool get _canManage =>
      widget.roomState.members
          .where((member) => member.userId == widget.currentUserId)
          .firstOrNull
          ?.canControlPlayback ??
      false;

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

    final isMobile =
        widget.onExpand != null || MediaQuery.sizeOf(context).width < 600;

    final useExpandedMobileHeader = isMobile && widget.isPanelExpanded;

    return queueState.when(
      // LOADING
      loading: () => const Center(child: CircularProgressIndicator()),

      // ERROR
      error: (error, stackTrace) => _QueueError(error: error),

      // DATA
      data: (items) {
        if (widget.onExpand != null && !widget.isPanelExpanded) {
          return QueueCollapsedPreview(
            onContentHeight: widget.onQueueContentHeight,
            playbackState: playbackState,
            items: items,
            showingHistory: showHistory,
            historyCount: historyItems.length,
            onExpand: widget.onExpand!,
            onAddTrack: () => _addTrack(context),
            onToggleHistory: hasHistory
                ? () {
                    setState(() => _showHistory = !showHistory);
                    widget.onExpand!();
                  }
                : null,
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Column(
            children: [
              // QUEUE STATUS
              //
              // ОСТАЁТСЯ ВСЕГДА.
              // History заменяет только список ниже.
              if (useExpandedMobileHeader)
                ExpandedMobileQueueToolbar(
                  items: items,
                  canManage: true,
                  onAddTrack: () => _addTrack(context),
                  hasHistory: hasHistory,
                  showHistory: showHistory,
                  onToggleHistory: hasHistory
                      ? () {
                          setState(() {
                            _showHistory = !showHistory;
                          });
                        }
                      : null,
                )
              else
                QueueStatusHeader(
                  playbackState: playbackState,
                  items: items,
                  canManage: true,
                  onAddTrack: () => _addTrack(context),
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

              SizedBox(height: useExpandedMobileHeader ? 8 : 14),

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
              // HISTORY
              if (showHistory)
                Expanded(
                  child: RoomPlaybackHistoryView(
                    items: historyItems,
                    canManage: true,
                    allowContentScroll: widget.allowContentScroll,
                    onScrollHandoff: widget.onScrollHandoff,
                    onAddToQueue: (item) {
                      return _addHistoryTrack(context, item);
                    },
                  ),
                )
              // EMPTY QUEUE
              else if (items.isEmpty)
                Expanded(
                  child: _EmptyQueue(
                    onScrollHandoff: widget.onScrollHandoff,
                    allowContentScroll: widget.allowContentScroll,
                  ),
                )
              // NORMAL QUEUE
              else
                Expanded(
                  child: canManage
                      ? DraggableQueue(
                          roomId: widget.roomId,
                          items: items,
                          onScrollHandoff: widget.onScrollHandoff,
                          allowContentScroll: widget.allowContentScroll,
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
                      : ReadOnlyQueue(
                          items: items,
                          onScrollHandoff: widget.onScrollHandoff,
                          allowContentScroll: widget.allowContentScroll,
                        ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ADD

  Future<void> _addTrack(BuildContext context) async {
    final track = await showTrackSearchDialog(context);

    if (track == null) {
      return;
    }

    if (!context.mounted) return;
    if (!_canManage) {
      await confirmRoomRequest(
        context,
        ref,
        roomId: widget.roomId,
        action: RoomAction.addTrack,
        payload: {
          'track_id': track.trackId,
          'title': track.title,
          'thumbnail_url': track.thumbnailUrl,
          'duration_ms': track.durationMs,
          'source': track.source,
        },
      );
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
      if (context.mounted) {
        AppNotice.show(context, 'Added to queue.', kind: NoticeKind.success);
      }
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      AppNotice.show(
        context,
        'Failed to add track: $error',
        kind: NoticeKind.error,
      );
    }
  }

  // ADD FROM HISTORY

  Future<void> _addHistoryTrack(
    BuildContext context,
    RoomPlaybackHistoryItem item,
  ) async {
    if (!_canManage) {
      await confirmRoomRequest(
        context,
        ref,
        roomId: widget.roomId,
        action: RoomAction.addTrack,
        payload: {
          'track_id': item.trackId,
          'title': item.title,
          'thumbnail_url': item.thumbnailUrl,
          'duration_ms': item.durationMs,
          'source': item.source,
        },
      );
      return;
    }
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

      AppNotice.show(context, 'Added to queue.', kind: NoticeKind.success);
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      AppNotice.show(
        context,
        'Failed to add track: $error',
        kind: NoticeKind.error,
      );
    }
  }

  // REMOVE

  Future<void> _removeTrack(BuildContext context, String itemId) async {
    if (_confirmingRemoval || !_canManage) return;
    _confirmingRemoval = true;
    try {
      final item = ref
          .read(queueControllerProvider(widget.roomId))
          .value
          ?.where((item) => item.id == itemId)
          .firstOrNull;
      if (item == null) return;
      final confirmed = await AppDialog.confirm(
        context,
        title: 'Remove track?',
        message: 'Remove “${item.title ?? item.trackId}” from the queue?',
        confirmLabel: 'Remove',
        destructive: true,
        icon: Icons.delete_outline_rounded,
      );
      if (!confirmed || !context.mounted || !_canManage) return;
      await ref
          .read(queueControllerProvider(widget.roomId).notifier)
          .removeItem(itemId);
      if (context.mounted) {
        AppNotice.show(
          context,
          'Track removed from queue.',
          kind: NoticeKind.success,
        );
      }
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      AppNotice.show(
        context,
        'Failed to remove track: $error',
        kind: NoticeKind.error,
      );
    } finally {
      _confirmingRemoval = false;
    }
  }
}

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue({this.onScrollHandoff, this.allowContentScroll = true});

  final RoomPanelScrollHandoff? onScrollHandoff;

  final bool allowContentScroll;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: const Alignment(0, -0.28),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        physics: allowContentScroll
            ? roomPanelScrollPhysics(
                onHandoff: onScrollHandoff,
                allowContentScroll: true,
              )
            : const NeverScrollableScrollPhysics(),
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

// ERROR

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
