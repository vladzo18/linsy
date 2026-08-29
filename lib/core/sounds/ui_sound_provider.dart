import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/app_sound_settings.dart';
import 'ui_sound_service.dart';

final uiSoundServiceProvider = Provider<UiSoundService>((ref) {
  final service = UiSoundService();

  // ===============================================================
  // APPLY CURRENT SETTINGS
  // ===============================================================

  final currentSettings = ref.read(appSoundSettingsProvider).value;

  if (currentSettings != null) {
    service.setEnabled(currentSettings.enabled);

    service.setVolume(currentSettings.volume);
  }

  // ===============================================================
  // WATCH FUTURE SETTINGS CHANGES
  // ===============================================================

  ref.listen(appSoundSettingsProvider, (previous, next) {
    final settings = next.value;

    if (settings == null) {
      return;
    }

    service.setEnabled(settings.enabled);

    service.setVolume(settings.volume);
  });

  // ===============================================================
  // DISPOSE
  // ===============================================================

  ref.onDispose(() {
    unawaited(service.dispose());
  });

  return service;
});
