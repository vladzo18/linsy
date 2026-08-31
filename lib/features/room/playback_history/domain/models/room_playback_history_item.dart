class RoomPlaybackHistoryItem {
  const RoomPlaybackHistoryItem({
    required this.id,
    required this.roomId,
    required this.source,
    required this.trackId,
    required this.title,
    required this.thumbnailUrl,
    required this.durationMs,
    required this.playedAt,
    required this.playCount,
  });

  final String id;
  final String roomId;

  final String source;
  final String trackId;

  final String? title;
  final String? thumbnailUrl;
  final int? durationMs;

  final DateTime playedAt;

  final int playCount;

  factory RoomPlaybackHistoryItem.fromMap(Map<String, dynamic> map) {
    return RoomPlaybackHistoryItem(
      id: map['id'] as String,
      roomId: map['room_id'] as String,

      source: map['source'] as String,
      trackId: map['track_id'] as String,

      title: map['title'] as String?,
      thumbnailUrl: map['thumbnail_url'] as String?,

      durationMs: (map['duration_ms'] as num?)?.toInt(),

      playedAt: DateTime.parse(map['played_at'] as String).toUtc(),

      playCount: (map['play_count'] as num?)?.toInt() ?? 1,
    );
  }
}
