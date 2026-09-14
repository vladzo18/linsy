import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linsy/features/room/domain/models/playback_state.dart';
import 'package:linsy/features/room/player/room_playback_notification.dart';

PlaybackState track(String title, {bool playing = true}) => PlaybackState(
  trackId: title, source: 'youtube', title: title, thumbnailUrl: null,
  durationMs: 180000, addedBy: 'host', isPlaying: playing, positionMs: 12000,
  updatedAt: DateTime(2026), scheduledStartAt: null, transitionKind: null, updatedBy: null,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/room-playback');
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async { calls.add(call); return null; });
  });
  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
    .setMockMethodCallHandler(channel, null));
  test('publishes track and pause changes, then stops when leaving', () async {
    final bridge = RoomPlaybackNotification('room', channel: channel);
    bridge.update(track('First'));
    await Future<void>.delayed(Duration.zero);
    bridge.update(track('Second', playing: false));
    await Future<void>.delayed(Duration.zero);
    await bridge.dispose();
    expect(calls.map((call) => call.method), ['update', 'update', 'stop']);
    expect(calls[0].arguments['title'], 'First');
    expect(calls[1].arguments['title'], 'Second');
    expect(calls[1].arguments['playing'], false);
    expect(calls.last.arguments['roomId'], 'room');
  });
  test('exit discards queued updates and cannot restart the notification', () async {
    final bridge = RoomPlaybackNotification('room', channel: channel);
    bridge.update(track('Late track'));
    await bridge.dispose();
    bridge.update(track('After exit'));
    await Future<void>.delayed(Duration.zero);
    expect(calls.map((call) => call.method), ['stop']);
  });
  test('empty playback removes the notification', () async {
    final bridge = RoomPlaybackNotification('room', channel: channel);
    bridge.update(PlaybackState.empty());
    await Future<void>.delayed(Duration.zero);
    expect(calls.single.method, 'stop');
    await bridge.dispose();
  });
}
