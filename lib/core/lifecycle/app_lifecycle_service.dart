import 'dart:async';
import 'dart:ui';

import 'package:flutter/scheduler.dart';

class AppLifecycleService {
  AppLifecycleService() : _state = SchedulerBinding.instance.lifecycleState;

  AppLifecycleState? _state;

  final StreamController<AppLifecycleState> _stateController =
      StreamController<AppLifecycleState>.broadcast(sync: true);

  AppLifecycleState? get state => _state;

  bool get isForeground => _state == AppLifecycleState.resumed;

  Stream<AppLifecycleState> get states => _stateController.stream;

  void handleStateChanged(AppLifecycleState state) {
    if (_state == state) {
      return;
    }

    _state = state;

    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  Future<void> dispose() async {
    await _stateController.close();
  }
}
