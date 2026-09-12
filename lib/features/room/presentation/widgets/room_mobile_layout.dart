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

  bool _dragging = false;

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
        _dragging = true;
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
      _dragging = false;
      _panelFraction = target;
      _panelExpandedState = target == _expandedFraction;
    });
  }

  // PANEL

  void _handleDragStart(DragStartDetails details) {
    setState(() {
      _dragging = true;
    });
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
      _dragging = false;
      _panelFraction = target;
      _panelExpandedState = target == _expandedFraction;
    });
  }

  void _togglePanel() {
    final target = _panelExpandedState ? _collapsedFraction : _expandedFraction;

    setState(() {
      _dragging = false;
      _contentHandoffActive = false;
      _panelFraction = target;
      _panelExpandedState = target == _expandedFraction;
    });
  }
  // BUILD

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;

        final keyboardVisible = View.of(context).viewInsets.bottom > 0;

        final playerHeight = (height * 0.43).clamp(280.0, 370.0).toDouble();

        // While the keyboard is open, the work panel temporarily takes the
        // whole room area. This keeps Chat/Search usable on real phones and
        // prevents the player from consuming half of the remaining viewport.
        // The stored panel state is not changed, so closing the keyboard
        // returns the user to the previous collapsed/expanded state.
        final effectivePanelFraction = keyboardVisible
            ? _expandedFraction
            : _panelFraction;

        final effectivePanelExpanded = keyboardVisible || _panelExpandedState;

        final panelHeight = height * effectivePanelFraction;

        // MINI PLAYER PROGRESS
        //
        // 0.64 -> invisible
        // 1.00 -> fully visible

        final showMiniPlayer = effectivePanelExpanded;

        final expansionProgress =
            ((effectivePanelFraction - _collapsedFraction) /
                    (_expandedFraction - _collapsedFraction))
                .clamp(0.0, 1.0)
                .toDouble();

        // Scroll permission and visual expanded state remain stable during
        // a handoff gesture. This lets one continuous drag collapse the panel.
        final allowContentScroll = effectivePanelExpanded;
        final isPanelExpanded = effectivePanelExpanded;

        return Stack(
          fit: StackFit.expand,
          children: [
            // NORMAL MOBILE ROOM
            Column(
              children: [
                SizedBox(
                  height: playerHeight,
                  child: RoomPlayerSection(
                    roomId: widget.roomId,
                    roomState: widget.roomState,
                    currentUserId: widget.currentUserId,
                  ),
                ),

                const SizedBox(height: 6),

                RoomSocialBar(
                  roomId: widget.roomId,
                  roomState: widget.roomState,
                  currentUserId: widget.currentUserId,
                  compact: true,
                ),

                const Expanded(child: SizedBox.shrink()),
              ],
            ),

            // BACKGROUND DIM
            if (effectivePanelFraction > _collapsedFraction)
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: Colors.black.withValues(
                      alpha: expansionProgress * 0.12,
                    ),
                  ),
                ),
              ),

            // SHEET
            Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedContainer(
                duration: _dragging
                    ? Duration.zero
                    : const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                width: double.infinity,
                height: panelHeight,
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    // GRABBER
                    RoomPanelHandle(
                      expanded: effectivePanelExpanded,
                      keyboardVisible: keyboardVisible,
                      onTap: keyboardVisible
                          ? () => FocusScope.of(context).unfocus()
                          : _togglePanel,
                      onDragStart: _handleDragStart,
                      onDragUpdate: (details) =>
                          _handleDragUpdate(details, height),
                      onDragEnd: _handleDragEnd,
                    ),
                    // MINI PLAYER
                    //
                    // Высота и opacity растут вместе с sheet,
                    // поэтому он не появляется резким скачком.
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: SizedBox(
                        height: showMiniPlayer ? 66 : 0,
                        child: ClipRect(
                          child: AnimatedOpacity(
                            opacity: showMiniPlayer ? 1 : 0,
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            child: RoomMiniPlayer(
                              roomId: widget.roomId,
                              roomState: widget.roomState,
                              currentUserId: widget.currentUserId,
                            ),
                          ),
                        ),
                      ),
                    ),

                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: showMiniPlayer ? 1 : 0,
                      color: colorScheme.outlineVariant.withValues(
                        alpha: showMiniPlayer ? 0.55 : 0,
                      ),
                    ),

                    // CHAT / QUEUE / REQUESTS
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
                          behavior: HitTestBehavior.translucent,

                          // While collapsed, the panel owns the vertical drag.
                          // While expanded, the inner scrollable owns it and
                          // hands the gesture back when it reaches the top.
                          onVerticalDragStart: allowContentScroll
                              ? null
                              : _handleDragStart,

                          onVerticalDragUpdate: allowContentScroll
                              ? null
                              : (details) {
                                  _handleDragUpdate(details, height);
                                },

                          onVerticalDragEnd: allowContentScroll
                              ? null
                              : _handleDragEnd,

                          child: RoomWorkPanel(
                            roomId: widget.roomId,
                            roomState: widget.roomState,
                            currentUserId: widget.currentUserId,
                            embedded: true,
                            isPanelExpanded: isPanelExpanded,
                            onExpand: () {
                              if (!_panelExpandedState) _togglePanel();
                            },
                            allowContentScroll: allowContentScroll,

                            onScrollHandoff: (dragDelta, metrics) {
                              if (View.of(context).viewInsets.bottom > 0) {
                                return false;
                              }
                              return _handleContentScrollHandoff(
                                dragDelta,
                                metrics,
                                height,
                              );
                            },
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
