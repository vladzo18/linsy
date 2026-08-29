import 'package:flutter/material.dart';
import 'package:linsy/features/room/domain/models/room_action_request.dart';
import 'package:linsy/features/room/live_reactions/room_reaction_button.dart';
import 'dart:async';
import '../../chat/presentation/widgets/room_chat.dart';
import '../controllers/room_state.dart';
import 'room_action_requests_section.dart';
import 'room_participants_bar.dart';
import 'room_player_section.dart';
import 'room_queue_section.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../chat/presentation/controllers/room_chat_controller.dart';
import '../controllers/action_request_controller.dart';
import '../controllers/queue_controller.dart';
import '../../../../core/sounds/ui_sound.dart';
import '../../../../core/sounds/ui_sound_provider.dart';
import '../../live_reactions/room_live_reactions_layer.dart';

class RoomContentLayout extends StatelessWidget {
  const RoomContentLayout({
    required this.roomId,
    required this.roomState,
    required this.currentUserId,
    super.key,
  });

  final String roomId;
  final RoomState roomState;
  final String? currentUserId;

  static const double _desktopBreakpoint = 900;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= _desktopBreakpoint;

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 10 : 8,
            vertical: isDesktop ? 10 : 8,
          ),
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ===========================================================
                // EXISTING ROOM UI
                // ===========================================================
                isDesktop
                    ? _DesktopRoomLayout(
                        roomId: roomId,
                        roomState: roomState,
                        currentUserId: currentUserId,
                      )
                    : _MobileRoomLayout(
                        roomId: roomId,
                        roomState: roomState,
                        currentUserId: currentUserId,
                      ),

                // ===========================================================
                // LIVE REACTIONS
                // ===========================================================
                RoomLiveReactionsLayer(roomId: roomId),
              ],
            ),
          ),
        );
      },
    );
  }
}

// =====================================================================
// DESKTOP
// =====================================================================

class _DesktopRoomLayout extends StatelessWidget {
  const _DesktopRoomLayout({
    required this.roomId,
    required this.roomState,
    required this.currentUserId,
  });

  final String roomId;
  final RoomState roomState;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final leftFlex = width >= 1600 ? 7 : 6;

        final rightFlex = width >= 1600 ? 5 : 4;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // =====================================================
            // LEFT
            // =====================================================
            Expanded(
              flex: leftFlex,
              child: Column(
                children: [
                  // =================================================
                  // PLAYER
                  // =================================================
                  Expanded(
                    child: RoomPlayerSection(
                      roomId: roomId,
                      roomState: roomState,
                      currentUserId: currentUserId,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // =================================================
                  // PARTICIPANTS
                  // =================================================
                  _RoomSocialBar(
                    roomId: roomId,
                    roomState: roomState,
                    currentUserId: currentUserId,
                    compact: false,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // =====================================================
            // CHAT / QUEUE / REQUESTS
            // =====================================================
            Expanded(
              flex: rightFlex,
              child: _RoomWorkPanel(
                roomId: roomId,
                roomState: roomState,
                currentUserId: currentUserId,
              ),
            ),
          ],
        );
      },
    );
  }
}

// =====================================================================
// MOBILE
// =====================================================================

class _MobileRoomLayout extends StatelessWidget {
  const _MobileRoomLayout({
    required this.roomId,
    required this.roomState,
    required this.currentUserId,
  });

  final String roomId;
  final RoomState roomState;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;

        // Оставляем нормальное место рабочей
        // панели после player + participants.
        final playerHeight = (height * 0.43).clamp(280.0, 370.0).toDouble();

        return Column(
          children: [
            // =====================================================
            // PLAYER
            // =====================================================
            SizedBox(
              height: playerHeight,
              child: RoomPlayerSection(
                roomId: roomId,
                roomState: roomState,
                currentUserId: currentUserId,
              ),
            ),

            const SizedBox(height: 6),

            // =====================================================
            // PARTICIPANTS
            // =====================================================
            _RoomSocialBar(
              roomId: roomId,
              roomState: roomState,
              currentUserId: currentUserId,
              compact: true,
            ),

            const SizedBox(height: 6),

            // =====================================================
            // WORK AREA
            // =====================================================
            Expanded(
              child: _RoomWorkPanel(
                roomId: roomId,
                roomState: roomState,
                currentUserId: currentUserId,
              ),
            ),
          ],
        );
      },
    );
  }
}

// =====================================================================
// SOCIAL BAR
// =====================================================================

class _RoomSocialBar extends StatelessWidget {
  const _RoomSocialBar({
    required this.roomId,
    required this.roomState,
    required this.currentUserId,
    required this.compact,
  });

  final String roomId;
  final RoomState roomState;
  final String? currentUserId;

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: RoomParticipantsBar(
              roomId: roomId,
              roomState: roomState,
              currentUserId: currentUserId,
            ),
          ),

          SizedBox(width: compact ? 6 : 8),

          RoomReactionButton(
            roomId: roomId,
            currentUserId: currentUserId,
            compact: compact,
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// WORK PANEL
// =====================================================================

class _RoomWorkPanel extends ConsumerStatefulWidget {
  const _RoomWorkPanel({
    required this.roomId,
    required this.roomState,
    required this.currentUserId,
  });

  final String roomId;
  final RoomState roomState;
  final String? currentUserId;

  @override
  ConsumerState<_RoomWorkPanel> createState() => _RoomWorkPanelState();
}

class _RoomWorkPanelState extends ConsumerState<_RoomWorkPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  int _currentTab = 0;

  bool _chatHasNew = false;
  bool _queueHasNew = false;
  bool _requestsHaveNew = false;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 3, vsync: this);

    _tabController.addListener(_handleTabChanged);
  }

  // ===================================================================
  // ROOM STATE CHANGES
  // ===================================================================

  @override
  void didUpdateWidget(covariant _RoomWorkPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Реагируем только когда комната уже полностью загружена.
    if (oldWidget.roomState.status != RoomStatus.ready ||
        widget.roomState.status != RoomStatus.ready) {
      return;
    }

    final oldMemberIds = oldWidget.roomState.members
        .map((member) => member.userId)
        .toSet();

    final newMemberIds = widget.roomState.members
        .map((member) => member.userId)
        .toSet();

    // Если набор участников вообще не изменился —
    // это мог быть role/profile/rebuild и т.д.
    if (oldMemberIds.length == newMemberIds.length &&
        oldMemberIds.containsAll(newMemberIds)) {
      return;
    }

    final currentUserId = widget.currentUserId;

    // ===============================================================
    // JOINED
    // ===============================================================

    final joinedIds = newMemberIds
        .difference(oldMemberIds)
        .where((id) => id != currentUserId)
        .toSet();

    // ===============================================================
    // LEFT
    // ===============================================================

    final leftIds = oldMemberIds
        .difference(newMemberIds)
        .where((id) => id != currentUserId)
        .toSet();

    if (joinedIds.isNotEmpty) {
      unawaited(ref.read(uiSoundServiceProvider).play(UiSound.memberJoin));
    }

    if (leftIds.isNotEmpty) {
      unawaited(ref.read(uiSoundServiceProvider).play(UiSound.memberLeave));
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);

    _tabController.dispose();

    super.dispose();
  }

  // ===================================================================
  // TAB
  // ===================================================================

  void _handleTabChanged() {
    final index = _tabController.index;

    if (index == _currentTab) {
      return;
    }

    _currentTab = index;

    setState(() {
      switch (index) {
        case 0:
          _chatHasNew = false;

        case 1:
          _queueHasNew = false;

        case 2:
          _requestsHaveNew = false;
      }
    });
  }

  // ===================================================================
  // NEW FLAGS
  // ===================================================================

  void _markChatNew() {
    if (_currentTab == 0 || _chatHasNew) {
      return;
    }

    setState(() {
      _chatHasNew = true;
    });
  }

  void _markQueueNew() {
    if (_currentTab == 1 || _queueHasNew) {
      return;
    }

    setState(() {
      _queueHasNew = true;
    });
  }

  void _markRequestsNew() {
    if (_currentTab == 2 || _requestsHaveNew) {
      return;
    }

    setState(() {
      _requestsHaveNew = true;
    });
  }

  // ===================================================================
  // CHAT SOUND
  // ===================================================================

  bool _hasNewIncomingMessage(
    List<dynamic> oldMessages,
    List<dynamic> newMessages,
  ) {
    if (newMessages.isEmpty) {
      return false;
    }

    final currentUserId = widget.currentUserId;

    if (currentUserId == null) {
      return false;
    }

    // ===============================================================
    // ROOM WAS EMPTY
    // ===============================================================

    if (oldMessages.isEmpty) {
      return newMessages.any((message) => message.userId != currentUserId);
    }

    // ===============================================================
    // KNOWN IDS
    // ===============================================================

    final oldIds = oldMessages.map((message) => message.id).toSet();

    // ===============================================================
    // LATEST MESSAGE WE ALREADY KNEW
    //
    // Это позволяет отличить:
    //
    // realtime:
    //   старое -> старое -> NEW
    //
    // pagination:
    //   OLD -> OLD -> старое -> старое
    // ===============================================================

    DateTime latestKnownTime = oldMessages.first.createdAt;

    for (final message in oldMessages.skip(1)) {
      if (message.createdAt.isAfter(latestKnownTime)) {
        latestKnownTime = message.createdAt;
      }
    }

    // ===============================================================
    // FIND ACTUAL NEW INCOMING MESSAGE
    // ===============================================================

    for (final message in newMessages) {
      // Уже было известно.
      if (oldIds.contains(message.id)) {
        continue;
      }

      // Собственное сообщение.
      if (message.userId == currentUserId) {
        continue;
      }

      // Это старое сообщение, добавленное pagination.
      if (!message.createdAt.isAfter(latestKnownTime)) {
        continue;
      }

      return true;
    }

    return false;
  }

  // ===================================================================
  // BUILD
  // ===================================================================

  @override
  Widget build(BuildContext context) {
    // ===============================================================
    // CHAT CHANGES
    // ===============================================================

    ref.listen(roomChatControllerProvider(widget.roomId), (previous, next) {
      final oldMessages = previous?.value;

      final newMessages = next.value;

      // =============================================================
      // INITIAL LOAD
      //
      // История комнаты загрузилась впервые —
      // никаких уведомлений.
      // =============================================================

      if (oldMessages == null || newMessages == null) {
        return;
      }

      // =============================================================
      // ANY CHAT CHANGE
      //
      // Красная точка работает как раньше.
      // =============================================================

      final oldSignature = oldMessages.map((message) => message.id).join('|');

      final newSignature = newMessages.map((message) => message.id).join('|');

      if (oldSignature == newSignature) {
        return;
      }

      _markChatNew();

      // =============================================================
      // SOUND
      // =============================================================

      if (_hasNewIncomingMessage(oldMessages, newMessages)) {
        unawaited(ref.read(uiSoundServiceProvider).play(UiSound.message));
      }
    });

    // ===============================================================
    // QUEUE CHANGES
    // ===============================================================

    ref.listen(queueControllerProvider(widget.roomId), (previous, next) {
      final oldItems = previous?.value;

      final newItems = next.value;

      if (oldItems == null || newItems == null) {
        return;
      }

      final oldSignature = oldItems.map((item) => item.id).join('|');

      final newSignature = newItems.map((item) => item.id).join('|');

      if (oldSignature != newSignature) {
        _markQueueNew();
      }
    });

    // ===============================================================
    // REQUEST CHANGES
    // ===============================================================

    ref.listen(actionRequestControllerProvider(widget.roomId), (
      previous,
      next,
    ) {
      final oldRequests = previous?.value;

      final newRequests = next.value;

      // Initial load:
      // никаких точек и никаких звуков.
      if (oldRequests == null || newRequests == null) {
        return;
      }

      // =============================================================
      // VISUAL NEW FLAG
      //
      // Оставляем прежнее поведение:
      // изменение списка / статуса показывает красную точку,
      // если Requests сейчас не открыта.
      // =============================================================

      final oldSignature = oldRequests
          .map(
            (request) =>
                '${request.id}:'
                '${request.status}',
          )
          .join('|');

      final newSignature = newRequests
          .map(
            (request) =>
                '${request.id}:'
                '${request.status}',
          )
          .join('|');

      if (oldSignature != newSignature) {
        _markRequestsNew();
      }

      // =============================================================
      // SOUND
      //
      // Звук нужен только host/moderator.
      // =============================================================

      final currentUserId = widget.currentUserId;

      if (currentUserId == null) {
        return;
      }

      final canHandleRequests = widget.roomState.members.any(
        (member) => member.userId == currentUserId && member.canControlPlayback,
      );

      if (!canHandleRequests) {
        return;
      }

      // =============================================================
      // NEW REQUEST IDS
      //
      // Нас интересует именно НОВАЯ запись.
      //
      // pending -> approved
      // pending -> rejected
      // не должны издавать звук.
      // =============================================================

      final oldIds = oldRequests.map((request) => request.id).toSet();

      final hasNewPendingRequest = newRequests.any((request) {
        if (oldIds.contains(request.id)) {
          return false;
        }

        if (request.status != RoomActionRequestStatus.pending) {
          return false;
        }

        // На всякий случай не уведомляем
        // пользователя о его собственной записи.
        if (request.userId == currentUserId) {
          return false;
        }

        return true;
      });

      if (!hasNewPendingRequest) {
        return;
      }

      unawaited(ref.read(uiSoundServiceProvider).play(UiSound.request));
    });

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // =========================================================
          // TABS
          // =========================================================
          SizedBox(
            height: 60,
            child: TabBar(
              controller: _tabController,
              isScrollable: false,
              dividerHeight: 0,
              indicatorSize: TabBarIndicatorSize.tab,
              labelPadding: EdgeInsets.zero,
              tabs: [
                _WorkTab(
                  icon: Icons.chat_bubble_outline,
                  label: 'Chat',
                  showNew: _chatHasNew,
                ),

                _WorkTab(
                  icon: Icons.queue_music,
                  label: 'Queue',
                  showNew: _queueHasNew,
                ),

                _WorkTab(
                  icon: Icons.notifications_none,
                  label: 'Requests',
                  showNew: _requestsHaveNew,
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // =========================================================
          // CONTENT
          // =========================================================
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                RoomChat(roomId: widget.roomId, height: null, embedded: true),

                RoomQueueSection(
                  roomId: widget.roomId,
                  roomState: widget.roomState,
                  currentUserId: widget.currentUserId,
                ),

                _ScrollableRoomPane(
                  child: RoomActionRequestsSection(
                    roomId: widget.roomId,
                    roomState: widget.roomState,
                    currentUserId: widget.currentUserId,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkTab extends StatelessWidget {
  const _WorkTab({
    required this.icon,
    required this.label,
    required this.showNew,
  });

  final IconData icon;
  final String label;
  final bool showNew;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tab(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // =====================================================
          // ICON + NEW DOT
          // =====================================================
          SizedBox(
            width: 30,
            height: 24,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(child: Center(child: Icon(icon, size: 22))),

                if (showNew)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colorScheme.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 2),

          Text(label),
        ],
      ),
    );
  }
}

// =====================================================================
// INTERNAL SCROLL
// =====================================================================

class _ScrollableRoomPane extends StatelessWidget {
  const _ScrollableRoomPane({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.all(12),
        child: child,
      ),
    );
  }
}
