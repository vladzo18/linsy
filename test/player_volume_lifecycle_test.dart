import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linsy/core/settings/playback_settings.dart';
import 'package:linsy/features/room/player/player_engine.dart';
import 'package:linsy/features/room/player/player_engine_provider.dart';
import 'package:linsy/features/room/player/player_volume_controller.dart';

class _Settings extends PlaybackSettingsController {
  @override
  Future<PlaybackSettings> build() async =>
      const PlaybackSettings(defaultVolume: 0.45);
}

class _Engine extends MockPlayerEngine {
  double? volume;
  bool disposed = false;
  @override
  Future<void> setVolume(double value) async {
    volume = value;
  }

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

void main() {
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.windows);
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test('$platform uses system volume despite saved player gain', () async {
      debugDefaultTargetPlatformOverride = platform;
      final engine = _Engine();
      final container = ProviderContainer(
        overrides: [
          playbackSettingsProvider.overrideWith(_Settings.new),
          platformPlayerEngineProvider.overrideWithValue(engine),
        ],
      );
      addTearDown(container.dispose);
      final session = container.listen(playerEngineProvider, (_, _) {});
      addTearDown(session.close);
      await container.read(playbackSettingsProvider.future);
      await container.pump();
      await container.read(playerVolumeProvider.notifier).setVolume(0);
      expect(container.read(playerVolumeProvider), 1);
      expect(engine.volume, 1);
    });
  }
  for (final desired in [0.0, 0.17, 0.85]) {
    test(
      'reentering room restores slider volume $desired on a fresh engine',
      () async {
        final engines = <_Engine>[];
        final container = ProviderContainer(
          overrides: [
            playbackSettingsProvider.overrideWith(_Settings.new),
            platformPlayerEngineProvider.overrideWith((ref) {
              final engine = _Engine();
              engines.add(engine);
              ref.onDispose(engine.dispose);
              return engine;
            }),
          ],
        );
        addTearDown(container.dispose);
        var session = container.listen(playerEngineProvider, (_, next) {});
        await container.read(playbackSettingsProvider.future);
        await container.pump();
        await container.read(playerVolumeProvider.notifier).setVolume(desired);
        expect(engines.single.volume, desired);
        session.close();
        await container.pump();
        expect(engines.single.disposed, isTrue);
        expect(container.read(playerVolumeProvider), desired);
        session = container.listen(playerEngineProvider, (_, next) {});
        await container.pump();
        expect(engines.length, 2);
        expect(engines.last.volume, desired);
        expect(container.read(playerVolumeProvider), desired);
        session.close();
      },
    );
  }
}
