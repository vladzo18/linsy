import '../../live_reactions/room_live_reactions_layer.dart';
import 'package:flutter/material.dart';
import '../controllers/room_state.dart';
import 'room_player_section.dart';
import 'room_mini_player.dart';
import 'room_social_bar.dart';
import 'room_work_panel.dart';
import 'room_panel_handle.dart';

class MobileRoomLayout extends StatefulWidget {
  const MobileRoomLayout({
    super.key,
    required this.roomId,
    required this.roomState,
    required this.currentUserId,
  });

  final String roomId;
  final RoomState roomState;
  final String? currentUserId;

  @override
  State<MobileRoomLayout> createState() => _MobileRoomLayoutState();
}

class _MobileRoomLayoutState extends State<MobileRoomLayout> {
  static const double _collapsedFraction = 0.48;

  // Теперь expanded действительно занимает
  // всю область под AppBar.
  static const double _expandedFraction = 1.0;

  double _panelFraction = _collapsedFraction;

  // Stable visual state. It changes only after a drag/snap finishes.
  // This prevents the mini-player/header from flickering while dragging.
  bool _panelExpandedState = false;

  // True only while an already-expanded inner scrollable is handing
  // a downward drag back to the room panel.
  bool _contentHandoffActive = false;

  // CONTENT SCROLL HANDOFF

  bool _handleContentScrollHandoff(
    double dragDelta,
    ScrollMetrics metrics,
    double availableHeight,
  ) {
    if (availableHeight <= 0) {
      return false;
    }

    final atTop = metrics.pixels <= metrics.minScrollExtent + 1;

    // When the expanded list reaches its top and the user keeps
    // dragging down, the SAME gesture starts moving the room panel.
    if (dragDelta > 0 && atTop && _panelFraction > _collapsedFraction) {
      final delta = dragDelta / availableHeight;

      final next = (_panelFraction - delta)
          .clamp(_collapsedFraction, _expandedFraction)
          .toDouble();

      setState(() {
        _contentHandoffActive = true;

        _panelFraction = next;
      });

      return true;
    }

    // Allow reversing the same handoff gesture upward before release.
    if (dragDelta < 0 &&
        _contentHandoffActive &&
        _panelFraction < _expandedFraction) {
      final delta = -dragDelta / availableHeight;

      final next = (_panelFraction + delta)
          .clamp(_collapsedFraction, _expandedFraction)
          .toDouble();

      setState(() {
        _panelFraction = next;
      });

      return true;
    }

    return false;
  }

  void _finishContentHandoff(double velocity) {
    if (!_contentHandoffActive) {
      return;
    }

    final double target;

    if (velocity > 500) {
      target = _collapsedFraction;
    } else if (velocity < -500) {
      target = _expandedFraction;
    } else {
      // A modest pull is enough to intentionally collapse the panel.
      target = _panelFraction <= 0.86 ? _collapsedFraction : _expandedFraction;
    }

    setState(() {
      _contentHandoffActive = false;

      _panelFraction = target;
      _panelExpandedState = target == _expandedFraction;
    });
  }

  // PANEL

  void _handleDragStart(DragStartDetails details) {
    setState(() {});
  }

  void _handleDragUpdate(DragUpdateDetails details, double availableHeight) {
    if (availableHeight <= 0) {
      return;
    }

    final delta = -details.delta.dy / availableHeight;

    final next = (_panelFraction + delta)
        .clamp(_collapsedFraction, _expandedFraction)
        .toDouble();

    setState(() {
      _panelFraction = next;
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;

    final double target;

    if (velocity < -500) {
      target = _expandedFraction;
    } else if (velocity > 500) {
      target = _collapsedFraction;
    } else {
      final middle = (_collapsedFraction + _expandedFraction) / 2;

      target = _panelFraction >= middle
          ? _expandedFraction
          : _collapsedFraction;
    }

    setState(() {
      _panelFraction = target;
      _panelExpandedState = target == _expandedFraction;
    });
  }

  void _togglePanel() {
    final target = _panelExpandedState ? _collapsedFraction : _expandedFraction;

    setState(() {
      _contentHandoffActive = false;
      _panelFraction = target;
      _panelExpandedState = target == _expandedFraction;
    });
  }
  // BUILD

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final keyboard = View.of(context).viewInsets.bottom > 0;
        final videoHeight = (constraints.maxWidth * 9 / 16).clamp(160.0, 270.0);
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final fullHeight = videoHeight + 110 * textScale.clamp(1.0, 2.0);
        // Reserve space for the handle, tabs and useful panel content, not just
        // the player. The participants strip and both gaps also consume height.
        final minimumPanelHeight = 300 * textScale.clamp(1.0, 1.4);
        final expanded =
            keyboard ||
            _panelExpandedState ||
            _panelFraction > 0.7 ||
            constraints.maxHeight < fullHeight + 62 + 16 + minimumPanelHeight;
        final compactHeight = 100 * textScale.clamp(1.0, 1.5);
        final playerHeight = expanded ? compactHeight : fullHeight;
        final showVideo = constraints.maxHeight >= playerHeight + 100;
        final panelHeight =
            constraints.maxHeight -
            (showVideo ? playerHeight + 8 + (expanded ? 0 : 70) : 74);
        return Column(
          children: [
            if (showVideo)
              SizedBox(
                height: playerHeight,
                child: RoomPlayerSection(
                  compactHeader: expanded,
                  roomId: widget.roomId,
                  roomState: widget.roomState,
                  currentUserId: widget.currentUserId,
                ),
              )
            else
              SizedBox(
                height: 66,
                child: RoomMiniPlayer(
                  roomId: widget.roomId,
                  roomState: widget.roomState,
                  currentUserId: widget.currentUserId,
                ),
              ),
            const SizedBox(height: 8),
            if (showVideo && !expanded) ...[
              SizedBox(
                height: 62,
                child: RoomSocialBar(
                  roomId: widget.roomId,
                  roomState: widget.roomState,
                  currentUserId: widget.currentUserId,
                  compact: true,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    if (!showVideo)
                      const Text(
                        'Video hidden · Playback paused on this device',
                        style: TextStyle(fontSize: 11),
                      ),
                    RoomPanelHandle(
                      expanded: expanded,
                      keyboardVisible: keyboard,
                      onTap: keyboard
                          ? () => FocusScope.of(context).unfocus()
                          : _togglePanel,
                      onDragStart: _handleDragStart,
                      onDragUpdate: (details) =>
                          _handleDragUpdate(details, constraints.maxHeight),
                      onDragEnd: _handleDragEnd,
                    ),
                    Expanded(
                      child: NotificationListener<ScrollEndNotification>(
                        onNotification: (notification) {
                          if (_contentHandoffActive) {
                            _finishContentHandoff(
                              notification.dragDetails?.primaryVelocity ?? 0,
                            );
                          }
                          return false;
                        },
                        child: GestureDetector(
                          onVerticalDragStart: expanded
                              ? null
                              : _handleDragStart,
                          onVerticalDragUpdate: expanded
                              ? null
                              : (details) => _handleDragUpdate(
                                  details,
                                  constraints.maxHeight,
                                ),
                          onVerticalDragEnd: expanded ? null : _handleDragEnd,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              RoomWorkPanel(
                                roomId: widget.roomId,
                                roomState: widget.roomState,
                                currentUserId: widget.currentUserId,
                                embedded: true,
                                isPanelExpanded: expanded,
                                allowContentScroll: expanded,
                                onExpand: () {
                                  if (!_panelExpandedState) _togglePanel();
                                },
                                onScrollHandoff: (delta, metrics) => keyboard
                                    ? false
                                    : _handleContentScrollHandoff(
                                        delta,
                                        metrics,
                                        panelHeight,
                                      ),
                              ),
                              RoomLiveReactionsLayer(roomId: widget.roomId),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
