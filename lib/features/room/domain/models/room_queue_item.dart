class RoomQueueItem {
  final String id;
  final String roomId;
  final String source;
  final String trackId;
  final String? title;
  final String? thumbnailUrl;
  final int? durationMs;
  final int position;
  final String addedBy;
  final DateTime createdAt;

  const RoomQueueItem({
    required this.id,
    required this.roomId,
    required this.source,
    required this.trackId,
    required this.title,
    required this.thumbnailUrl,
    required this.durationMs,
    required this.position,
    required this.addedBy,
    required this.createdAt,
  });
}
