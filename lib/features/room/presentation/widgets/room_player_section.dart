import 'package:linsy/core/feedback/app_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/room_action_request.dart';
import 'confirm_room_request.dart';
import '../controllers/playback_controller.dart';
import '../controllers/queue_controller.dart';
import '../controllers/room_state.dart';
import '../providers/playback_position_provider.dart';
import 'room_player_card.dart';

class RoomPlayerSection extends ConsumerWidget {
  const RoomPlayerSection({
    required this.roomId,
    required this.roomState,
    required this.currentUserId,
    super.key,
    this.compactHeader = false,
  });

  final String roomId;
  final bool compactHeader;
  final RoomState roomState;
  final String? currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playbackState = ref.watch(playbackControllerProvider(roomId));

    final queueState = ref.watch(queueControllerProvider(roomId));

    return playbackState.when(
      loading: () => const _PlaybackLoadingCard(),

      error: (error, stackTrace) => _PlaybackErrorCard(error: error),

      data: (playback) {
        final currentMember = roomState.members
            .where((member) => member.userId == currentUserId)
            .firstOrNull;

        final canControlPlayback = currentMember?.canControlPlayback ?? false;

        final livePositionMs =
            ref.watch(playbackPositionProvider(roomId)).value ??
            playback.positionMs;

        // =====================================================
        // NEXT TRACK
        // =====================================================
        //
        // QueueController хранит очередь
        // в фактическом порядке воспроизведения.
        //
        // Первый элемент очереди —
        // следующий трек.
        //
        // Если очередь ещё загружается,
        // упала с ошибкой или пуста —
        // nextTrack будет null.
        // =====================================================

        final queueItems = queueState.value;

        final nextTrack = queueItems?.firstOrNull;

        return RoomPlayerCard(
          compactHeader: compactHeader,
          playback: playback,

          nextTrack: nextTrack,

          livePositionMs: livePositionMs,

          canControlPlayback: canControlPlayback,

          // =====================================================
          // HOST / MODERATOR
          // =====================================================
          onPlayPause: () {
            return ref
                .read(playbackControllerProvider(roomId).notifier)
                .setPlaying(!playback.isPlaying);
          },

          onNext: () async {
            try {
              await ref
                  .read(playbackControllerProvider(roomId).notifier)
                  .next();
            } catch (error) {
              if (!context.mounted) {
                return;
              }

              final message = error.toString().contains('Queue is empty')
                  ? 'Queue is empty.'
                  : 'Failed to play next track.';

              AppNotice.show(context, message, kind: NoticeKind.error);
            }
          },

          onSeek: (positionMs) {
            return ref
                .read(playbackControllerProvider(roomId).notifier)
                .seek(positionMs);
          },

          // =====================================================
          // MEMBER
          // =====================================================
          onRequestPlayPause: () => confirmRoomRequest(
            context,
            ref,
            roomId: roomId,
            action: playback.isPlaying ? RoomAction.pause : RoomAction.play,
          ),
          onRequestNext: () => confirmRoomRequest(
            context,
            ref,
            roomId: roomId,
            action: RoomAction.next,
          ),
          onRequestSeek: (positionMs) => confirmRoomRequest(
            context,
            ref,
            roomId: roomId,
            action: RoomAction.seek,
            payload: {'position_ms': positionMs < 0 ? 0 : positionMs},
          ),
        );
      },
    );
  }
}

// =====================================================================
// LOADING
// =====================================================================

class _PlaybackLoadingCard extends StatelessWidget {
  const _PlaybackLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

// =====================================================================
// ERROR
// =====================================================================

class _PlaybackErrorCard extends StatelessWidget {
  const _PlaybackErrorCard({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Text(
                'Failed to load playback: '
                '$error',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
