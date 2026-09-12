import 'package:flutter/material.dart';
import '../../domain/models/room_action_request.dart';

class RequestActionIcon extends StatelessWidget {
  const RequestActionIcon({
    super.key,
    required this.action,
    this.compact = false,
  });

  final RoomAction action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final size = compact ? 26.0 : 36.0;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(compact ? 8 : 10),
      ),
      child: Icon(
        requestActionIcon(action),
        size: compact ? 16 : 20,
        color: colorScheme.onPrimaryContainer,
      ),
    );
  }
}

// STATUS

class RequestStatusBadge extends StatelessWidget {
  const RequestStatusBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onSecondaryContainer,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// EMPTY

class EmptyRequests extends StatelessWidget {
  const EmptyRequests({
    super.key,
    required this.title,
    required this.subtitle,
    this.error = false,
  });

  final String title;
  final String subtitle;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              error ? Icons.error_outline : Icons.notifications_none_rounded,
              size: 40,
              color: error ? colorScheme.error : colorScheme.onSurfaceVariant,
            ),

            const SizedBox(height: 10),

            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),

            const SizedBox(height: 4),

            Text(
              subtitle,
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

// HELPERS

IconData requestActionIcon(RoomAction action) {
  switch (action) {
    case RoomAction.play:
      return Icons.play_arrow_rounded;

    case RoomAction.pause:
      return Icons.pause_rounded;

    case RoomAction.seek:
      return Icons.fast_forward_rounded;

    case RoomAction.next:
      return Icons.skip_next_rounded;

    case RoomAction.addTrack:
      return Icons.add_to_queue_rounded;
  }
}

String requestName(RoomAction action) {
  switch (action) {
    case RoomAction.play:
      return 'Play';

    case RoomAction.pause:
      return 'Pause';

    case RoomAction.seek:
      return 'Seek';

    case RoomAction.next:
      return 'Next track';

    case RoomAction.addTrack:
      return 'Add track';
  }
}

String? requestPayloadText(RoomActionRequest request) {
  if (request.action == RoomAction.seek) {
    final position = request.payload?['position_ms'];

    if (position is num) {
      return formatRequestTime(position.toInt());
    }
  }

  if (request.action == RoomAction.addTrack) {
    final title = request.payload?['title'];

    if (title is String && title.isNotEmpty) {
      return title;
    }

    final trackId = request.payload?['track_id'];

    if (trackId is String && trackId.isNotEmpty) {
      return trackId;
    }
  }

  return null;
}

String requestInitial(String name) {
  if (name.isEmpty) {
    return '?';
  }

  return name.characters.first.toUpperCase();
}

String formatRequestTime(int milliseconds) {
  final totalSeconds = milliseconds ~/ 1000;

  final hours = totalSeconds ~/ 3600;

  final minutes = (totalSeconds % 3600) ~/ 60;

  final seconds = totalSeconds % 60;

  if (hours > 0) {
    return '$hours:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  return '$minutes:'
      '${seconds.toString().padLeft(2, '0')}';
}
