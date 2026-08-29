import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_windows/webview_flutter_windows.dart';

import 'player_engine_provider.dart';
import 'windows_youtube_player_engine.dart';
import 'youtube_player_engine.dart';

class PlayerSurface extends ConsumerWidget {
  const PlayerSurface({required this.trackId, super.key});

  final String? trackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (trackId == null) {
      return const SizedBox.shrink();
    }

    final engine = ref.watch(playerEngineProvider);

    // =================================================
    // ANDROID / IOS
    // =================================================

    if (engine is YoutubePlayerEngine) {
      return FutureBuilder<void>(
        future: engine.ready,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _PlayerMessage(
              icon: Icons.error_outline,
              title: 'Player error',
              message: '${snapshot.error}',
            );
          }

          if (snapshot.connectionState != ConnectionState.done) {
            return const _PlayerLoading();
          }

          return AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ColoredBox(
                color: Colors.black,

                // IMPORTANT:
                //
                // This WebView is now a real child
                // of the Flutter layout.
                //
                // It is NOT placed inside
                // youtube_player_iframe's
                // OverlayPortal.
                child: WebViewWidget(
                  controller: engine.controller.webViewController,
                ),
              ),
            ),
          );
        },
      );
    }

    // =================================================
    // WINDOWS
    // =================================================

    if (engine is WindowsYoutubePlayerEngine) {
      return FutureBuilder<void>(
        future: engine.ready,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _PlayerMessage(
              icon: Icons.error_outline,
              title: 'Windows player error',
              message: '${snapshot.error}',
            );
          }

          if (snapshot.connectionState != ConnectionState.done) {
            return const _PlayerLoading();
          }

          return AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ColoredBox(
                color: Colors.black,
                child: IgnorePointer(
                  ignoring: true,
                  child: Webview(engine.controller),
                ),
              ),
            ),
          );
        },
      );
    }

    // =================================================
    // FALLBACK
    // =================================================

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.music_note, size: 48, color: Colors.white54),
      ),
    );
  }
}

// =====================================================================
// LOADING
// =====================================================================

class _PlayerLoading extends StatelessWidget {
  const _PlayerLoading();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),

            SizedBox(height: 12),

            Text('Loading player...', style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// ERROR
// =====================================================================

class _PlayerMessage extends StatelessWidget {
  const _PlayerMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: Colors.redAccent),

            const SizedBox(height: 12),

            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
