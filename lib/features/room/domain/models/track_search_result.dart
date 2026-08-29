class TrackSearchResult {
  final String source;
  final String trackId;
  final String title;
  final String channelTitle;
  final String? thumbnailUrl;
  final int? durationMs;

  const TrackSearchResult({
    required this.source,
    required this.trackId,
    required this.title,
    required this.channelTitle,
    required this.thumbnailUrl,
    required this.durationMs,
  });

  factory TrackSearchResult.fromJson(Map<String, dynamic> json) {
    return TrackSearchResult(
      source: json['source'] as String,
      trackId: json['trackId'] as String,
      title: json['title'] as String,
      channelTitle: json['channelTitle'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      durationMs: (json['durationMs'] as num?)?.toInt(),
    );
  }
}
