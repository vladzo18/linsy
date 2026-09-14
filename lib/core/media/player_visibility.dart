import 'package:flutter/foundation.dart';

/// App-wide playback eligibility. The application has one active room player.
final playerVisibility = PlayerVisibility();

// The private Windows client supports background listening. Mobile keeps the
// visible-video lifecycle policy.
bool get requiresVisibleVideo =>
    kIsWeb || defaultTargetPlatform != TargetPlatform.windows;

class PlayerVisibility extends ChangeNotifier {
  final Map<Object, bool> _surfaces = {};
  int _blockers = 0;
  bool get blocked => _blockers > 0;
  bool get allowed =>
      (!requiresVisibleVideo || !blocked) &&
      _surfaces.values.any((visible) => visible);

  void report(Object owner, bool visible) {
    if (_surfaces[owner] == visible) return;
    _surfaces[owner] = visible;
    notifyListeners();
  }

  void remove(Object owner) {
    if (_surfaces.remove(owner) != null) notifyListeners();
  }

  VoidCallback block() {
    _blockers++;
    notifyListeners();
    var released = false;
    return () {
      if (released) return;
      released = true;
      _blockers--;
      notifyListeners();
    };
  }
}
