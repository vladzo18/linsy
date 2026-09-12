import 'dart:async';
import 'package:flutter/foundation.dart';
import 'player_volume_controller.dart';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'player_engine.dart';
import 'windows_youtube_player_engine.dart';
import 'youtube_player_engine.dart';

final platformPlayerEngineProvider = Provider.autoDispose<PlayerEngine>((ref) {
  late final PlayerEngine engine;

  if (Platform.isWindows) {
    engine = WindowsYoutubePlayerEngine();
  } else if (Platform.isAndroid || Platform.isIOS) {
    engine = YoutubePlayerEngine();
  } else {
    engine = MockPlayerEngine();
  }

  ref.onDispose(engine.dispose);

  return engine;
});

// Recreated for each playback session; the UI volume outlives that session.
final playerEngineProvider = Provider.autoDispose<PlayerEngine>((ref) {
  final engine = ref.watch(platformPlayerEngineProvider);
  final volume = ref.read(playerVolumeProvider);
  unawaited(
    engine.setVolume(volume).catchError((Object error, StackTrace stack) {
      debugPrint('Failed to restore player volume: $error');
    }),
  );
  return engine;
});
