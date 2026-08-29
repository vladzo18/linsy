import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/time/server_clock.dart';
import '../controllers/playback_controller.dart';

final playbackPositionProvider = StreamProvider.autoDispose.family<int, String>(
  (ref, roomId) async* {
    final playbackAsync = ref.watch(playbackControllerProvider(roomId));

    final clock = await ref.watch(serverClockProvider.future);

    final playback = playbackAsync.value;

    if (playback == null) {
      yield 0;
      return;
    }

    // Сразу отдаём актуальную позицию.
    yield playback.positionAt(clock.now());

    // На паузе ничего тикать не нужно.
    if (!playback.isPlaying) {
      return;
    }

    // Только UI ticker.
    // Никаких запросов к Supabase здесь нет.
    while (true) {
      await Future<void>.delayed(const Duration(milliseconds: 250));

      yield playback.positionAt(clock.now());
    }
  },
);
