import 'package:linsy/core/feedback/app_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:linsy/features/profile/application/profile_store.dart';

import '../../domain/models/room_action_request.dart';
import 'confirm_room_request.dart';
import '../controllers/playback_controller.dart';
import '../controllers/queue_controller.dart';
import '../controllers/room_state.dart';
import '../providers/playback_position_provider.dart';

class RoomMiniPlayer extends ConsumerWidget {
  const RoomMiniPlayer({
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
    final playbackState = ref.watch(playbackControllerProvider(roomId));

    final queueState = ref.watch(queueControllerProvider(roomId));

    return playbackState.when(
      loading: () => const SizedBox(
        height: 66,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (error, stackTrace) => SizedBox(
        height: 66,
        child: Center(
          child: Text(
            'Playback unavailable',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ),
      data: (playback) {
        final trackId = playback.trackId;

        if (trackId == null) {
          return const SizedBox(
            height: 66,
            child: Center(child: Text('Nothing playing')),
          );
        }

        final currentMember = roomState.members
            .where((member) => member.userId == currentUserId)
            .firstOrNull;

        final canControlPlayback = currentMember?.canControlPlayback ?? false;

        final canInteract = currentUserId != null;

        final livePositionMs =
            ref.watch(playbackPositionProvider(roomId)).value ??
            playback.positionMs;

        final durationMs = playback.durationMs ?? 0;

        final progress = durationMs > 0
            ? (livePositionMs / durationMs).clamp(0.0, 1.0).toDouble()
            : 0.0;

        final queueItems = queueState.value;

        final hasNext = queueItems != null && queueItems.isNotEmpty;

        final title = playback.title?.trim();

        final effectiveTitle = title == null || title.isEmpty ? trackId : title;

        // ADDED BY

        final addedByUserId = playback.addedBy;

        final addedByProfile = addedByUserId == null
            ? null
            : ref.watch(profileByIdProvider(addedByUserId));

        final addedByName = addedByProfile?.displayName?.trim();

        final addedByLabel = addedByName != null && addedByName.isNotEmpty
            ? addedByName
            : 'Linsy user';

        final colorScheme = Theme.of(context).colorScheme;

        return SizedBox(
          height: 66,
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 8, 5),
                  child: Row(
                    children: [
                      // COVER
                      _MiniArtwork(thumbnailUrl: playback.thumbnailUrl),

                      const SizedBox(width: 10),

                      // TITLE + STATUS + ADDED BY
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              effectiveTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            const SizedBox(height: 2),

                            Row(
                              children: [
                                Icon(
                                  playback.isPlaying
                                      ? Icons.graphic_eq_rounded
                                      : Icons.pause_rounded,
                                  size: 13,
                                  color: colorScheme.primary,
                                ),

                                const SizedBox(width: 4),

                                Text(
                                  playback.isPlaying ? 'Playing' : 'Paused',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                ),

                                if (addedByUserId != null) ...[
                                  Text(
                                    '  •  ',
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),

                                  Icon(
                                    Icons.person_outline_rounded,
                                    size: 12,
                                    color: colorScheme.onSurfaceVariant,
                                  ),

                                  const SizedBox(width: 3),

                                  Expanded(
                                    child: Text(
                                      'Added by $addedByLabel',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),

                      // PLAY / PAUSE
                      IconButton(
                        tooltip: playback.isPlaying ? 'Pause' : 'Play',
                        onPressed: !canInteract
                            ? null
                            : () async {
                                if (canControlPlayback) {
                                  await ref
                                      .read(
                                        playbackControllerProvider(
                                          roomId,
                                        ).notifier,
                                      )
                                      .setPlaying(!playback.isPlaying);

                                  return;
                                }

                                await confirmRoomRequest(
                                  context,
                                  ref,
                                  roomId: roomId,
                                  action: playback.isPlaying
                                      ? RoomAction.pause
                                      : RoomAction.play,
                                );
                              },
                        icon: Icon(
                          playback.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                      ),

                      // NEXT
                      if (hasNext)
                        IconButton(
                          tooltip: 'Next track',
                          onPressed: !canInteract
                              ? null
                              : () async {
                                  if (canControlPlayback) {
                                    try {
                                      await ref
                                          .read(
                                            playbackControllerProvider(
                                              roomId,
                                            ).notifier,
                                          )
                                          .next();
                                    } catch (error) {
                                      if (!context.mounted) {
                                        return;
                                      }

                                      AppNotice.show(
                                        context,
                                        'Failed to play next track.',
                                        kind: NoticeKind.error,
                                      );
                                    }

                                    return;
                                  }

                                  await confirmRoomRequest(
                                    context,
                                    ref,
                                    roomId: roomId,
                                    action: RoomAction.next,
                                  );
                                },
                          icon: const Icon(Icons.skip_next_rounded),
                        ),
                    ],
                  ),
                ),
              ),

              // PROGRESS
              LinearProgressIndicator(
                value: durationMs > 0 ? progress : null,
                minHeight: 2,
                backgroundColor: colorScheme.surfaceContainerHighest,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ARTWORK

class _MiniArtwork extends StatelessWidget {
  const _MiniArtwork({required this.thumbnailUrl});

  final String? thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    final url = thumbnailUrl?.trim();

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 46,
        height: 46,
        child: url == null || url.isEmpty
            ? _fallback(context)
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _fallback(context);
                },
              ),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.music_note_rounded,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
