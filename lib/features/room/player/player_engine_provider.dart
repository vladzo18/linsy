import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'player_engine.dart';
import 'windows_youtube_player_engine.dart';
import 'youtube_player_engine.dart';

final playerEngineProvider =
    Provider.autoDispose<PlayerEngine>(
  (ref) {
    late final PlayerEngine engine;

    if (Platform.isWindows) {
      engine =
          WindowsYoutubePlayerEngine();
    } else if (
      Platform.isAndroid ||
      Platform.isIOS
    ) {
      engine =
          YoutubePlayerEngine();
    } else {
      engine =
          MockPlayerEngine();
    }

    ref.onDispose(
      engine.dispose,
    );

    return engine;
  },
);