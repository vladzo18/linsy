import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/track_search_result.dart';
import '../../domain/repositories/track_search_repository.dart';

class SupabaseTrackSearchRepository implements TrackSearchRepository {
  SupabaseTrackSearchRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<TrackSearchResult>> search(String query) async {
    final cleanQuery = query.trim();

    if (cleanQuery.length < 2) {
      return [];
    }

    // ============================================================
    // YOUTUBE URL
    // ============================================================

    final videoId = _extractYoutubeVideoId(cleanQuery);

    // Если пользователь вставил ссылку на конкретное видео,
    // просим Edge Function получить именно это видео.
    //
    // Если это обычный текст —
    // используем старый текстовый поиск.
    final body = videoId != null
        ? <String, dynamic>{'videoId': videoId}
        : <String, dynamic>{'query': cleanQuery};

    // ============================================================
    // EDGE FUNCTION
    // ============================================================

    final response = await _client.functions.invoke(
      'youtube-search',
      body: body,
    );

    final data = response.data;

    if (data is! Map) {
      throw StateError('Invalid response from youtube-search.');
    }

    final rawItems = data['items'];

    if (rawItems is! List) {
      throw StateError('youtube-search did not return items.');
    }

    return rawItems
        .whereType<Map>()
        .map(
          (item) => TrackSearchResult.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }
}

// =====================================================================
// YOUTUBE URL
// =====================================================================

String? _extractYoutubeVideoId(String input) {
  var value = input.trim();

  if (value.isEmpty) {
    return null;
  }

  // ---------------------------------------------------------------
  // Позволяем вставлять ссылки без https://
  //
  // youtube.com/watch?v=...
  // www.youtube.com/watch?v=...
  // youtu.be/...
  // ---------------------------------------------------------------

  final lower = value.toLowerCase();

  if (lower.startsWith('youtube.com/') ||
      lower.startsWith('www.youtube.com/') ||
      lower.startsWith('m.youtube.com/') ||
      lower.startsWith('music.youtube.com/') ||
      lower.startsWith('youtu.be/') ||
      lower.startsWith('www.youtu.be/')) {
    value = 'https://$value';
  }

  // ---------------------------------------------------------------
  // URI
  // ---------------------------------------------------------------

  final uri = Uri.tryParse(value);

  if (uri == null || uri.host.isEmpty) {
    return null;
  }

  final host = uri.host.toLowerCase();

  // ===============================================================
  // youtu.be/VIDEO_ID
  // ===============================================================

  if (host == 'youtu.be' || host == 'www.youtu.be') {
    if (uri.pathSegments.isEmpty) {
      return null;
    }

    return _validateYoutubeVideoId(uri.pathSegments.first);
  }

  // ===============================================================
  // youtube.com
  // ===============================================================

  final isYoutube =
      host == 'youtube.com' ||
      host == 'www.youtube.com' ||
      host == 'm.youtube.com' ||
      host == 'music.youtube.com' ||
      host == 'youtube-nocookie.com' ||
      host == 'www.youtube-nocookie.com';

  if (!isYoutube) {
    return null;
  }

  // ===============================================================
  // youtube.com/watch?v=VIDEO_ID
  // ===============================================================

  if (uri.path == '/watch') {
    return _validateYoutubeVideoId(uri.queryParameters['v']);
  }

  // ===============================================================
  // youtube.com/shorts/VIDEO_ID
  // youtube.com/live/VIDEO_ID
  // youtube.com/embed/VIDEO_ID
  // ===============================================================

  if (uri.pathSegments.length >= 2) {
    final type = uri.pathSegments.first;

    if (type == 'shorts' || type == 'live' || type == 'embed') {
      return _validateYoutubeVideoId(uri.pathSegments[1]);
    }
  }

  return null;
}

// =====================================================================
// VALIDATE VIDEO ID
// =====================================================================

String? _validateYoutubeVideoId(String? value) {
  if (value == null) {
    return null;
  }

  final id = value.trim();

  // Обычный YouTube video ID имеет 11 символов.
  final valid = RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id);

  if (!valid) {
    return null;
  }

  return id;
}
