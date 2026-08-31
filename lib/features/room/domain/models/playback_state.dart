class PlaybackState {
  final String? trackId;

  final String? source;
  final String? title;
  final String? thumbnailUrl;

  final int? durationMs;

  /// User who originally added/requested this track.
  final String? addedBy;

  final bool isPlaying;

  /// Checkpoint position.
  final int positionMs;

  /// Time when the playback row was last modified.
  final DateTime updatedAt;

  final DateTime? scheduledStartAt;

  final String? updatedBy;

  const PlaybackState({
    required this.trackId,
    required this.source,
    required this.title,
    required this.thumbnailUrl,
    required this.durationMs,
    required this.addedBy,
    required this.isPlaying,
    required this.positionMs,
    required this.updatedAt,
    required this.scheduledStartAt,
    required this.updatedBy,
  });

  factory PlaybackState.empty() {
    return PlaybackState(
      trackId: null,
      source: null,
      title: null,
      thumbnailUrl: null,
      durationMs: null,
      addedBy: null,
      isPlaying: false,
      positionMs: 0,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      scheduledStartAt: null,
      updatedBy: null,
    );
  }

  int positionAt(DateTime now) {
    var result = positionMs;

    if (!isPlaying) {
      return _clampPosition(result);
    }

    final utcNow = now.toUtc();

    final scheduled = scheduledStartAt?.toUtc();

    if (scheduled != null) {
      if (utcNow.isBefore(scheduled)) {
        return _clampPosition(result);
      }

      result += utcNow.difference(scheduled).inMilliseconds;

      return _clampPosition(result);
    }

    final elapsed = utcNow.difference(updatedAt.toUtc()).inMilliseconds;

    if (elapsed > 0) {
      result += elapsed;
    }

    return _clampPosition(result);
  }

  int _clampPosition(int value) {
    var result = value < 0 ? 0 : value;

    final duration = durationMs;

    if (duration != null && result > duration) {
      result = duration;
    }

    return result;
  }
}
