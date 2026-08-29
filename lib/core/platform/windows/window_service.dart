import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

typedef WindowCloseHandler = Future<void> Function();

abstract interface class WindowService {
  Future<void> initialize();
}

class PlatformWindowService with WindowListener implements WindowService {
  PlatformWindowService({required this._onCloseRequested});

  final WindowCloseHandler _onCloseRequested;

  bool _closing = false;

  @override
  Future<void> initialize() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
      return;
    }

    await windowManager.ensureInitialized();

    // ---------------------------------------------------------------
    // We intercept the native close request.
    //
    // This gives us time to leave the room
    // before Windows destroys the process.
    // ---------------------------------------------------------------

    windowManager.addListener(this);

    await windowManager.setPreventClose(true);

    const options = WindowOptions(
      size: Size(1200, 800),
      minimumSize: Size(1100, 700),
      center: true,
      title: 'Linsy',
      titleBarStyle: TitleBarStyle.normal,
    );

    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.center();
      await windowManager.show();
      await windowManager.focus();
    });
  }

  @override
  Future<void> onWindowClose() async {
    if (_closing) {
      return;
    }

    final preventClose = await windowManager.isPreventClose();

    if (!preventClose) {
      return;
    }

    _closing = true;

    try {
      // =============================================================
      // LEAVE ROOM
      // =============================================================

      await _onCloseRequested();
    } finally {
      // =============================================================
      // ACTUAL WINDOW CLOSE
      // =============================================================

      windowManager.removeListener(this);

      await windowManager.setPreventClose(false);

      await windowManager.destroy();
    }
  }
}
