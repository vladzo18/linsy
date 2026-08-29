class SavedTrack {
  const SavedTrack({
    required this.id,
    required this.userId,
    required this.source,
    required this.trackId,
    required this.title,
    required this.channelTitle,
    required this.thumbnailUrl,
    required this.durationMs,
    required this.createdAt,
  });

  final String id;

  final String userId;

  final String source;

  final String trackId;

  final String title;

  final String channelTitle;

  final String? thumbnailUrl;

  final int? durationMs;

  final DateTime createdAt;

  String get key => '$source:$trackId';
}
