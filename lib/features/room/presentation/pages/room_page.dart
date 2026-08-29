import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../data/providers/room_code_provider.dart';
import '../../data/providers/room_name_provider.dart';
import '../../player/playback_synchronizer.dart';
import '../controllers/room_controller.dart';
import '../controllers/room_state.dart';
import '../widgets/room_content_layout.dart';

class RoomPage extends ConsumerWidget {
  const RoomPage({required this.roomId, super.key});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomState = ref.watch(roomControllerProvider(roomId));

    final roomNameState = ref.watch(roomNameProvider(roomId));

    final roomCodeState = ref.watch(roomCodeProvider(roomId));

    final currentUser = ref.watch(authControllerProvider).user;

    ref.watch(playbackSynchronizerProvider(roomId));

    final roomName = roomNameState.value ?? 'Room';

    final roomCode = roomCodeState.value;

    final compact = MediaQuery.sizeOf(context).width < 700;

    return Scaffold(
      // =============================================================
      // APP BAR
      // =============================================================
      appBar: AppBar(
        title: Text(roomName, maxLines: 1, overflow: TextOverflow.ellipsis),

        actions: [
          // =========================================================
          // ROOM CODE
          // =========================================================
          if (roomCode != null && roomCode.isNotEmpty)
            _RoomCodeButton(roomCode: roomCode, compact: compact),

          // =========================================================
          // SETTINGS
          // =========================================================
          IconButton(
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const SettingsPage(),
                ),
              );
            },
            icon: const Icon(Icons.settings_outlined),
          ),

          // =========================================================
          // LEAVE
          // =========================================================
          IconButton(
            tooltip: 'Leave room',
            onPressed: roomState.status == RoomStatus.leaving
                ? null
                : () {
                    ref
                        .read(roomControllerProvider(roomId).notifier)
                        .leaveRoom();
                  },
            icon: const Icon(Icons.exit_to_app_rounded),
          ),

          const SizedBox(width: 8),
        ],
      ),

      // =============================================================
      // CONTENT
      // =============================================================
      body: ClipRect(
        child: RoomContentLayout(
          roomId: roomId,
          roomState: roomState,
          currentUserId: currentUser?.id,
        ),
      ),
    );
  }
}

// =====================================================================
// ROOM CODE BUTTON
// =====================================================================

class _RoomCodeButton extends StatefulWidget {
  const _RoomCodeButton({required this.roomCode, required this.compact});

  final String roomCode;
  final bool compact;

  @override
  State<_RoomCodeButton> createState() => _RoomCodeButtonState();
}

class _RoomCodeButtonState extends State<_RoomCodeButton> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.roomCode));

    if (!mounted) {
      return;
    }

    setState(() {
      _copied = true;
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Room code copied'),
          duration: Duration(milliseconds: 1200),
        ),
      );

    await Future<void>.delayed(const Duration(milliseconds: 1200));

    if (!mounted) {
      return;
    }

    setState(() {
      _copied = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final icon = _copied ? Icons.check_rounded : Icons.link_rounded;

    // ===============================================================
    // MOBILE
    // ===============================================================

    if (widget.compact) {
      return IconButton(
        tooltip: _copied ? 'Copied' : 'Copy room code',
        onPressed: _copy,
        icon: Icon(icon),
      );
    }

    // ===============================================================
    // DESKTOP
    // ===============================================================

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Tooltip(
        message: _copied ? 'Copied' : 'Copy room code',
        child: FilledButton.tonalIcon(
          onPressed: _copy,
          icon: Icon(icon, size: 18),
          label: Text(widget.roomCode),
          style: FilledButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
        ),
      ),
    );
  }
}
