import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_lifecycle_service.dart';

final appLifecycleServiceProvider = Provider<AppLifecycleService>((ref) {
  final service = AppLifecycleService();

  ref.onDispose(() {
    unawaited(service.dispose());
  });

  return service;
});
