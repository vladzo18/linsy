import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'player_engine.dart';

class YoutubePlayerEngine implements PlayerEngine {
  late final YoutubePlayerController controller;

  late final Future<void> ready;

  StreamSubscription<YoutubeVideoState>? _videoStateSubscription;

  StreamSubscription<YoutubePlayerValue>? _controllerSubscription;

  final StreamController<String> _endedController =
      StreamController<String>.broadcast();

  String? _trackId;

  bool _isPlaying = false;

  int _positionMs = 0;

  double _volume = 1.0;

  DateTime _positionUpdatedAt = DateTime.now();

  bool _wantPlaying = false;

  bool _soundEnabled = false;

  bool _soundEnabling = false;

  bool _pauseAfterAutoplayRunning = false;

  PlayerState? _lastPlayerState;

  YoutubePlayerEngine() {
    controller = YoutubePlayerController(
      params: const YoutubePlayerParams(
        showControls: false,
        showFullscreenButton: false,
        enableCaption: false,
        playsInline: true,
        privacyEnhancedMode: true,
        pointerEvents: PointerEvents.none,

        // Required for autoplay/preload.
        mute: true,

        videoStateUpdateInterval: 250,
      ),
    );

    _videoStateSubscription = controller.videoStateStream.listen((videoState) {
      _positionMs = videoState.position.inMilliseconds;

      _positionUpdatedAt = DateTime.now();
    });

    _controllerSubscription = controller.listen(_handleControllerValue);

    // YoutubePlayer widget used to call
    // controller.init() for us.
    //
    // We now render WebViewWidget directly,
    // so the engine owns initialization.
    ready = _initialize();
  }

  // ===================================================
  // INITIALIZATION
  // ===================================================

  Future<void> _initialize() async {
    await _configureAndroidWebView();

    await controller.initWithParams(params: controller.params);

    debugPrint(
      '[YoutubePlayer] '
      'Controller initialized',
    );
  }

  Future<void> _configureAndroidWebView() async {
    final platform = controller.webViewController.platform;

    if (platform is AndroidWebViewController) {
      await platform.setMediaPlaybackRequiresUserGesture(false);
    }
  }

  // ===================================================
  // CONTROLLER STATE
  // ===================================================

  void _handleControllerValue(YoutubePlayerValue value) {
    final playerState = value.playerState;

    if (playerState != _lastPlayerState) {
      debugPrint(
        '[YoutubePlayer] '
        'state: $playerState',
      );
    }

    _isPlaying = playerState == PlayerState.playing;

    // -------------------------------------------------
    // MUTED PRELOAD
    // -------------------------------------------------

    if (playerState == PlayerState.playing) {
      if (!_wantPlaying) {
        unawaited(_pauseAfterAutoplay());
      } else {
        unawaited(_tryEnableSound());
      }
    }

    // -------------------------------------------------
    // TRACK ENDED
    // -------------------------------------------------

    if (playerState == PlayerState.ended &&
        _lastPlayerState != PlayerState.ended) {
      final trackId = _trackId;

      if (trackId != null) {
        _endedController.add(trackId);
      }
    }

    _lastPlayerState = playerState;
  }

  // ===================================================
  // VOLUME
  // ===================================================

  @override
  Future<void> setVolume(double volume) async {
    await ready;

    final normalized = volume.clamp(0.0, 1.0).toDouble();

    _volume = normalized;

    final youtubeVolume = (_volume * 100).round();

    await controller.setVolume(youtubeVolume);

    if (_volume <= 0) {
      await controller.mute();

      return;
    }

    if (_wantPlaying) {
      await controller.unMute();
    }
  }

  Future<void> _pauseAfterAutoplay() async {
    if (_pauseAfterAutoplayRunning || _wantPlaying) {
      return;
    }

    _pauseAfterAutoplayRunning = true;

    try {
      await ready;

      await controller.pauseVideo();

      _isPlaying = false;

      debugPrint(
        '[YoutubePlayer] '
        'Preloaded and paused',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[YoutubePlayer] '
        'Preload pause failed: '
        '$error',
      );

      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _pauseAfterAutoplayRunning = false;
    }
  }

  Future<void> _tryEnableSound() async {
    if (!_wantPlaying || _soundEnabled || _soundEnabling) {
      return;
    }

    _soundEnabling = true;

    try {
      await ready;

      if (_volume <= 0) {
        await controller.mute();
      } else {
        await controller.setVolume((_volume * 100).round());

        await controller.unMute();
      }

      // Playback could have been paused
      // while awaiting WebView commands.
      if (!_wantPlaying) {
        await controller.mute();

        return;
      }

      _soundEnabled = true;

      debugPrint(
        '[YoutubePlayer] '
        'Sound enabled',
      );
    } finally {
      _soundEnabling = false;
    }
  }

  // ===================================================
  // STATE
  // ===================================================

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
    await ready;

    debugPrint(
      '[YoutubePlayer] '
      'LOAD $trackId '
      '@ $startPositionMs ms',
    );

    _trackId = trackId;

    _positionMs = startPositionMs;

    _positionUpdatedAt = DateTime.now();

    _isPlaying = false;

    _wantPlaying = false;

    _soundEnabled = false;

    _soundEnabling = false;

    _lastPlayerState = null;

    await controller.mute();

    await controller.loadVideoById(
      videoId: trackId,
      startSeconds: startPositionMs / 1000.0,
    );
  }

  // ===================================================
  // PLAY
  // ===================================================

  @override
  Future<void> play() async {
    await ready;

    if (_trackId == null) {
      return;
    }

    debugPrint('[YoutubePlayer] PLAY');

    _wantPlaying = true;

    await controller.playVideo();

    await _tryEnableSound();
  }

  // ===================================================
  // PAUSE
  // ===================================================

  @override
  Future<void> pause() async {
    await ready;

    _wantPlaying = false;

    debugPrint('[YoutubePlayer] PAUSE');

    await controller.pauseVideo();

    _isPlaying = false;
  }

  // ===================================================
  // SEEK
  // ===================================================

  @override
  Future<void> seek(int positionMs) async {
    await ready;

    final position = positionMs < 0 ? 0 : positionMs;

    debugPrint(
      '[YoutubePlayer] '
      'SEEK $position ms',
    );

    _positionMs = position;

    _positionUpdatedAt = DateTime.now();

    await controller.seekTo(seconds: position / 1000.0, allowSeekAhead: true);
  }

  // ===================================================
  // STOP
  // ===================================================

  @override
  Future<void> stop() async {
    await ready;

    debugPrint('[YoutubePlayer] STOP');

    _wantPlaying = false;

    _soundEnabled = false;

    _trackId = null;

    _positionMs = 0;

    _isPlaying = false;

    await controller.stopVideo();
  }

  // ===================================================
  // DISPOSE
  // ===================================================

  @override
  void dispose() {
    unawaited(_videoStateSubscription?.cancel());

    unawaited(_controllerSubscription?.cancel());

    unawaited(_endedController.close());

    unawaited(controller.close());
  }
}
