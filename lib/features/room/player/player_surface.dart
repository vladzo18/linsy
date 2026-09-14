import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_windows/webview_flutter_windows.dart';
import '../../../core/media/player_visibility.dart';
import 'room_pip.dart';
import 'player_engine_provider.dart';
import 'windows_youtube_player_engine.dart';
import 'youtube_player_engine.dart';

class PlayerSurface extends ConsumerWidget {
  const PlayerSurface({required this.trackId, super.key});
  final String? trackId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (trackId == null) return const SizedBox.shrink();
    final engine = ref.watch(playerEngineProvider);
    final Future<void> ready;
    final Widget video;
    if (engine is YoutubePlayerEngine) {
      ready = engine.ready;
      video = WebViewWidget(controller: engine.controller.webViewController);
    } else if (engine is WindowsYoutubePlayerEngine) {
      ready = engine.ready;
      video = Webview(engine.controller);
    } else {
      ready = Future.value();
      video = const ColoredBox(color: Colors.black);
    }
    return _VisibleEmbed(
      key: GlobalObjectKey(engine),
      ready: ready,
      child: video,
    );
  }
}

class _VisibleEmbed extends ConsumerStatefulWidget {
  const _VisibleEmbed({super.key, required this.ready, required this.child});
  final Future<void> ready;
  final Widget child;
  @override
  ConsumerState<_VisibleEmbed> createState() => _VisibleEmbedState();
}

class _VisibleEmbedState extends ConsumerState<_VisibleEmbed>
    with WidgetsBindingObserver {
  final _bounds = GlobalKey();
  Timer? _timer;
  bool _sizeAllowed = false;
  bool _ready = false;
  AppLifecycleState? _lifecycle;

  bool get _present {
    if (!requiresVisibleVideo) return true;
    final pip = ref.read(roomPipProvider);
    final foreground =
        _lifecycle == AppLifecycleState.resumed ||
        ((pip ||
                (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows)) &&
            _lifecycle == AppLifecycleState.inactive);
    return foreground &&
        _sizeAllowed &&
        !playerVisibility.blocked &&
        (ModalRoute.of(context)?.isCurrent ?? true);
  }

  @override
  void initState() {
    super.initState();
    _lifecycle = WidgetsBinding.instance.lifecycleState;
    WidgetsBinding.instance.addObserver(this);
    playerVisibility.addListener(_gateChanged);
    _timer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => _measure(),
    );
    widget.ready.then((_) {
      if (mounted) {
        _ready = true;
        _measure();
      }
    }, onError: (Object _) {});
  }

  void _gateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => _lifecycle = state);
    _measure();
  }

  void _measure() {
    if (!mounted) return;
    final box = _bounds.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final visible = rect.intersect(Offset.zero & MediaQuery.sizeOf(context));
    final enough =
        rect.width > 0 &&
        rect.height > 0 &&
        !visible.isEmpty &&
        visible.width * visible.height > rect.width * rect.height / 2;
    if (_sizeAllowed != enough) setState(() => _sizeAllowed = enough);
    playerVisibility.report(this, _present && _ready);
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    playerVisibility.removeListener(_gateChanged);
    playerVisibility.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(roomPipProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
        final present =
            _present && constraints.maxWidth > 0 && constraints.maxHeight > 0;
        return SizedBox.expand(
          key: _bounds,
          child: ColoredBox(
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Offstage(
                  offstage: !present,
                  child: FutureBuilder<void>(
                    future: widget.ready,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(child: Text('Player unavailable'));
                      }
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const _PlayerLoading();
                      }
                      return widget.child;
                    },
                  ),
                ),
                if (!present)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Playback paused locally.\nShow the video to resume.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
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
