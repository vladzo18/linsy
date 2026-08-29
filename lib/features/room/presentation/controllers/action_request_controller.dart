import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:linsy/features/room/presentation/controllers/playback_controller.dart';
import 'package:linsy/features/room/presentation/controllers/queue_controller.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/providers/action_request_repository_provider.dart';
import '../../domain/models/room_action_request.dart';

final actionRequestControllerProvider =
    AsyncNotifierProvider.family<
      ActionRequestController,
      List<RoomActionRequest>,
      String
    >(
      ActionRequestController.new,
    );

class ActionRequestController
    extends AsyncNotifier<List<RoomActionRequest>> {
  ActionRequestController(this.roomId);

  final String roomId;

  StreamSubscription<List<RoomActionRequest>>? _subscription;

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Future<List<RoomActionRequest>> build() async {
    final repository = ref.read(
      actionRequestRepositoryProvider,
    );

    _subscription = repository
        .watchRoomRequests(roomId)
        .listen(
          (requests) {
            state = AsyncData(requests);
          },
          onError: (
            Object error,
            StackTrace stackTrace,
          ) {
            state = AsyncError(
              error,
              stackTrace,
            );
          },
        );

    ref.onDispose(() {
      _subscription?.cancel();
    });

    return _loadInitialRequests();
  }

  // ============================================================
  // INITIAL LOAD
  // ============================================================

  Future<List<RoomActionRequest>> _loadInitialRequests() async {
    final repository = ref.read(
      actionRequestRepositoryProvider,
    );

    final completer =
        Completer<List<RoomActionRequest>>();

    late StreamSubscription<List<RoomActionRequest>>
        subscription;

    subscription = repository
        .watchRoomRequests(roomId)
        .listen(
          (requests) async {
            if (!completer.isCompleted) {
              completer.complete(requests);

              await subscription.cancel();
            }
          },
          onError: (
            Object error,
            StackTrace stackTrace,
          ) {
            if (!completer.isCompleted) {
              completer.completeError(
                error,
                stackTrace,
              );
            }
          },
        );

    return completer.future;
  }

  // ============================================================
  // CREATE
  // ============================================================

  Future<void> createRequest({
    required RoomAction action,
    Map<String, dynamic>? payload,
  }) async {
    final user = ref.read(
      authControllerProvider,
    ).user;

    if (user == null) {
      return;
    }

    try {
      await ref
          .read(
            actionRequestRepositoryProvider,
          )
          .createRequest(
            roomId: roomId,
            userId: user.id,
            action: action,
            payload: payload,
          );
    } catch (
      error,
      stackTrace
    ) {
      state = AsyncError(
        error,
        stackTrace,
      );
    }
  }

  // ============================================================
  // SEEK REQUEST
  // ============================================================

  Future<void> requestSeek(
    int positionMs,
  ) async {
    final safePosition =
        positionMs < 0
            ? 0
            : positionMs;

    await createRequest(
      action: RoomAction.seek,
      payload: {
        'position_ms':
            safePosition,
      },
    );
  }

  // ============================================================
  // CANCEL
  // ============================================================

  Future<void> cancelRequest(
    String requestId,
  ) async {
    try {
      await ref
          .read(
            actionRequestRepositoryProvider,
          )
          .cancelRequest(
            requestId: requestId,
          );
    } catch (
      error,
      stackTrace
    ) {
      state = AsyncError(
        error,
        stackTrace,
      );
    }
  }

  // ============================================================
  // APPROVE
  // ============================================================

  Future<void> approveRequest(
    RoomActionRequest request,
  ) async {
    final playback = ref.read(
      playbackControllerProvider(
        roomId,
      ).notifier,
    );

    switch (request.action) {
      case RoomAction.play:
        await playback.setPlaying(
          true,
        );
        break;

      case RoomAction.pause:
        await playback.setPlaying(
          false,
        );
        break;

      case RoomAction.seek:
        final position =
            request.payload?[
              'position_ms'
            ];

        if (position is! num) {
          throw StateError(
            'Seek request does not contain position_ms.',
          );
        }

        await playback.seek(
          position.toInt(),
        );

        break;

      case RoomAction.next:
        await playback.next();
        break;

      case RoomAction.addTrack:
        final payload =
            request.payload;

        final trackId =
            payload?['track_id'];

        if (trackId is! String ||
            trackId.trim().isEmpty) {
          throw StateError(
            'Add track request does not contain a valid track_id.',
          );
        }

        final title =
            payload?['title'];

        final thumbnailUrl =
            payload?[
              'thumbnail_url'
            ];

        final durationValue =
            payload?[
              'duration_ms'
            ];

        final source =
            payload?['source'];

        await ref
            .read(
              queueControllerProvider(
                roomId,
              ).notifier,
            )
            .addItem(
              trackId:
                  trackId.trim(),
              title:
                  title is String
                      ? title
                      : null,
              thumbnailUrl:
                  thumbnailUrl
                          is String
                      ? thumbnailUrl
                      : null,
              durationMs:
                  durationValue
                          is num
                      ? durationValue
                          .toInt()
                      : null,
              source:
                  source is String
                      ? source
                      : 'youtube',
            );

        break;
    }

    // Request becomes approved only after
    // the requested command succeeds.
    await _resolve(
      request.id,
      RoomActionRequestStatus.approved,
    );
  }

  // ============================================================
  // REJECT
  // ============================================================

  Future<void> rejectRequest(
    String requestId,
  ) async {
    await _resolve(
      requestId,
      RoomActionRequestStatus.rejected,
    );
  }

  // ============================================================
  // RESOLVE
  // ============================================================

  Future<void> _resolve(
    String requestId,
    RoomActionRequestStatus status,
  ) async {
    await ref
        .read(
          actionRequestRepositoryProvider,
        )
        .resolveRequest(
          requestId:
              requestId,
          status:
              status,
        );
  }
}