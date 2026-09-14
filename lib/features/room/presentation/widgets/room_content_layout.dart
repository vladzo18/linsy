import 'package:flutter/material.dart';
import '../controllers/room_state.dart';
import 'room_player_section.dart';
import '../../live_reactions/room_live_reactions_layer.dart';
import 'room_mobile_layout.dart';
import 'room_social_bar.dart';
import 'room_work_panel.dart';

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
                // EXISTING ROOM UI
                isDesktop
                    ? _DesktopRoomLayout(
                        roomId: roomId,
                        roomState: roomState,
                        currentUserId: currentUserId,
                      )
                    : MobileRoomLayout(
                        roomId: roomId,
                        roomState: roomState,
                        currentUserId: currentUserId,
                      ),

                // LIVE REACTIONS
              ],
            ),
          ),
        );
      },
    );
  }
}

// DESKTOP

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
            // LEFT
            Expanded(
              flex: leftFlex,
              child: Column(
                children: [
                  // PLAYER
                  Expanded(
                    child: RoomPlayerSection(
                      roomId: roomId,
                      roomState: roomState,
                      currentUserId: currentUserId,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // PARTICIPANTS
                  RoomSocialBar(
                    roomId: roomId,
                    roomState: roomState,
                    currentUserId: currentUserId,
                    compact: false,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // CHAT / QUEUE / REQUESTS
            Expanded(
              flex: rightFlex,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RoomWorkPanel(
                    roomId: roomId,
                    roomState: roomState,
                    currentUserId: currentUserId,
                  ),
                  RoomLiveReactionsLayer(roomId: roomId),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
