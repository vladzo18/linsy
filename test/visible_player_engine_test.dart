import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:linsy/core/media/player_visibility.dart';
import 'package:linsy/features/room/player/player_engine.dart';
import 'package:linsy/features/room/player/visible_player_engine.dart';

class _Engine extends MockPlayerEngine {
  final calls = <String>[];
  Completer<void>? pendingPlay;
  @override
  Future<void> load(String id, {int startPositionMs = 0}) async {
    calls.add('load');
  }

  @override
  Future<void> play() async {
    calls.add('play');
    await pendingPlay?.future;
  }

  @override
  Future<void> seek(int positionMs) async {
    calls.add('seek');
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
  }
}

void main() {
  test('hidden embed rejects loads, seeks and repeated sync starts', () async {
    final gate = PlayerVisibility();
    final raw = _Engine();
    final player = VisiblePlayerEngine(raw, gate);
    await player.load('track');
    await player.play();
    await player.seek(5000);
    await player.play();
    expect(raw.calls, ['pause']);
    gate.report('video', true);
    await player.load('track');
    await player.seek(10000);
    await player.play();
    expect(raw.calls, ['pause', 'load', 'seek', 'play']);
    player.dispose();
    gate.dispose();
  });

  test('hide during an in-flight start ends in a local pause', () async {
    final gate = PlayerVisibility()..report('video', true);
    final raw = _Engine()..pendingPlay = Completer<void>();
    final player = VisiblePlayerEngine(raw, gate);
    final playing = player.play();
    await Future<void>.delayed(Duration.zero);
    gate.report('video', false);
    raw.pendingPlay!.complete();
    await playing;
    await player.play();
    expect(raw.calls.first, 'play');
    expect(raw.calls.last, 'pause');
    expect(raw.calls.where((call) => call == 'play').length, 1);
    player.dispose();
    gate.dispose();
  });

  test('nested UI blockers must all close before playback is eligible', () {
    final gate = PlayerVisibility()..report('video', true);
    final first = gate.block();
    final second = gate.block();
    first();
    first();
    expect(gate.allowed, false);
    second();
    expect(gate.allowed, true);
    gate.remove('video');
    expect(gate.allowed, false);
    gate.dispose();
  });
}
