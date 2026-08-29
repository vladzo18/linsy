import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:webview_flutter_windows/webview_flutter_windows.dart';

import 'player_engine.dart';
import 'dart:math' as math;

class WindowsYoutubePlayerEngine implements PlayerEngine {
  final WebviewController controller = WebviewController();

  late final Future<void> ready;

  final Completer<void> _playerReady = Completer<void>();

  final StreamController<String> _endedController =
      StreamController<String>.broadcast();

  StreamSubscription<dynamic>? _messageSubscription;

  String? _trackId;

  bool _isPlaying = false;

  int _positionMs = 0;

  double _volume = 1.0;

  DateTime _positionUpdatedAt = DateTime.now();

  String? _lastPlayerState;

  bool _disposed = false;

  WindowsYoutubePlayerEngine() {
    ready = _initialize();
  }

  // ===================================================
  // INITIALIZE
  // ===================================================

  Future<void> _initialize() async {
    debugPrint(
      '[WindowsYoutubePlayer] '
      'Initializing WebView2...',
    );

    // YouTube playback is controlled by Linsy itself,
    // not by a button located inside the HTML page.
    //
    // Without this Chromium can treat unMute() after
    // playVideo() as autoplay with sound and pause it.
    await WebviewController.initializeEnvironment(
      additionalArguments: '--autoplay-policy=no-user-gesture-required',
    );

    await controller.initialize();

    await controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);

    await controller.setDefaultContextMenusEnabled(false);

    _messageSubscription = controller.webMessage.listen(
      _handleMessage,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint(
          '[WindowsYoutubePlayer] '
          'Web message error: $error',
        );

        debugPrintStack(stackTrace: stackTrace);
      },
    );

    // Flutter Windows кладёт assets рядом с exe:
    //
    // data/flutter_assets/assets/...
    //
    // WebView2 будет видеть эту папку как
    // настоящий HTTPS host.
    await controller.addVirtualHostNameMapping(
      'linsy.local',
      r'data\flutter_assets\assets\windows_player',
      WebviewHostResourceAccessKind.denyCors,
    );

    await controller.loadUrl('https://linsy.local/player.html');

    await _playerReady.future.timeout(const Duration(seconds: 20));

    debugPrint('[WindowsYoutubePlayer] READY');
  }

  // ===================================================
  // WEBVIEW MESSAGE
  // ===================================================

  void _handleMessage(dynamic rawMessage) {
    dynamic decoded = rawMessage;

    if (decoded is String) {
      try {
        decoded = jsonDecode(decoded);
      } catch (_) {
        return;
      }
    }

    if (decoded is! Map) {
      return;
    }

    final message = Map<String, dynamic>.from(decoded);

    final type = message['type'] as String?;

    switch (type) {
      case 'ready':
        if (!_playerReady.isCompleted) {
          _playerReady.complete();
        }

        return;

      case 'position':
        final messageTrackId = message['trackId'] as String?;

        if (messageTrackId != _trackId) {
          return;
        }

        final rawPosition = message['positionMs'];

        if (rawPosition is num) {
          _positionMs = rawPosition.toInt();

          _positionUpdatedAt = DateTime.now();
        }

        return;

      case 'state':
        final messageTrackId = message['trackId'] as String?;

        if (messageTrackId != null && messageTrackId != _trackId) {
          return;
        }

        final playerState = message['state'] as String?;

        if (playerState == null) {
          return;
        }

        if (playerState != _lastPlayerState) {
          debugPrint(
            '[WindowsYoutubePlayer] '
            'state: $playerState',
          );
        }

        _isPlaying = playerState == 'playing';

        if (playerState == 'ended' && _lastPlayerState != 'ended') {
          final trackId = _trackId;

          if (trackId != null) {
            _endedController.add(trackId);
          }
        }

        _lastPlayerState = playerState;

        return;

      case 'preloaded':
        debugPrint(
          '[WindowsYoutubePlayer] '
          'Preloaded and paused',
        );

        _isPlaying = false;

        return;

      case 'error':
        debugPrint(
          '[WindowsYoutubePlayer] '
          'YouTube error: '
          '${message['code']}',
        );

        return;

      case 'debug':
        debugPrint(
          '[WindowsYoutubePlayer JS] '
          '${message['message']}',
        );

        return;
    }
  }

  // ===================================================
  // SEND COMMAND
  // ===================================================

  Future<void> _send(Map<String, dynamic> message) async {
    await ready;

    if (_disposed) {
      return;
    }

    await controller.postWebMessage(jsonEncode(message));
  }

  // ===================================================
  // STATE
  // ===================================================

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0).toDouble();

    int youtubeVolume;

    if (_volume <= 0.0) {
      youtubeVolume = 0;
    } else {
      // WebView2 / YouTube становится
      // практически неслышным на совсем
      // маленьких значениях.
      //
      // Поэтому любое ненулевое значение
      // начинается примерно с 3%.
      //
      // Более мягкая perceptual curve:
      //
      // UI 10%  -> ~5%
      // UI 20%  -> ~10%
      // UI 30%  -> ~17%
      // UI 50%  -> ~35%
      // UI 70%  -> ~58%
      // UI 80%  -> ~71%
      // UI 100% -> 100%

      const minAudibleVolume = 3.0;

      final curved = math.pow(_volume, 1.25).toDouble();

      youtubeVolume = (minAudibleVolume + (100.0 - minAudibleVolume) * curved)
          .round();

      youtubeVolume = youtubeVolume.clamp(1, 100);
    }

    debugPrint(
      '[WindowsYoutubePlayer] '
      'VOLUME '
      'UI=${(_volume * 100).round()}% '
      'actual=$youtubeVolume%',
    );

    await _send({'command': 'setVolume', 'volume': youtubeVolume});
  }

  @override
  PlayerEngineState get currentState {
    var position = _positionMs;

    if (_isPlaying) {
      final elapsed = DateTime.now()
          .difference(_positionUpdatedAt)
          .inMilliseconds;

      if (elapsed > 0 && elapsed < 1000) {
        position += elapsed;
      }
    }

    return PlayerEngineState(
      trackId: _trackId,
      isPlaying: _isPlaying,
      positionMs: position,
    );
  }

  @override
  Stream<String> get endedTrackIds => _endedController.stream;

  // ===================================================
  // LOAD
  // ===================================================

  @override
  Future<void> load(String trackId, {int startPositionMs = 0}) async {
    debugPrint(
      '[WindowsYoutubePlayer] '
      'LOAD $trackId '
      '@ $startPositionMs ms',
    );

    _trackId = trackId;

    _positionMs = startPositionMs;

    _positionUpdatedAt = DateTime.now();

    _isPlaying = false;

    _lastPlayerState = null;

    await _send({
      'command': 'load',
      'trackId': trackId,
      'positionMs': startPositionMs,
    });
  }

  // ===================================================
  // PLAY
  // ===================================================

  @override
  Future<void> play() async {
    if (_trackId == null) {
      return;
    }

    debugPrint('[WindowsYoutubePlayer] PLAY');

    await _send({'command': 'play'});
  }
  // ===================================================
  // PAUSE
  // ===================================================

  @override
  Future<void> pause() async {
    if (_trackId == null) {
      return;
    }

    debugPrint('[WindowsYoutubePlayer] PAUSE');

    await _send({'command': 'pause'});
  }

  // ===================================================
  // SEEK
  // ===================================================

  @override
  Future<void> seek(int positionMs) async {
    final position = positionMs < 0 ? 0 : positionMs;

    debugPrint(
      '[WindowsYoutubePlayer] '
      'SEEK $position ms',
    );

    _positionMs = position;

    _positionUpdatedAt = DateTime.now();

    await _send({'command': 'seek', 'positionMs': position});
  }

  // ===================================================
  // STOP
  // ===================================================

  @override
  Future<void> stop() async {
    debugPrint('[WindowsYoutubePlayer] STOP');

    if (_trackId != null) {
      await _send({'command': 'stop'});
    }

    _trackId = null;

    _positionMs = 0;

    _positionUpdatedAt = DateTime.now();

    _isPlaying = false;

    _lastPlayerState = null;
  }

  // ===================================================
  // DISPOSE
  // ===================================================

  @override
  void dispose() {
    if (_disposed) {
      return;
    }

    _disposed = true;

    unawaited(_messageSubscription?.cancel());

    unawaited(_endedController.close());

    unawaited(controller.dispose());
  }
}
