import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/settings/appearance_settings.dart';
import 'app_exit_service.dart';
import 'router.dart';
import 'theme/app_theme_resolver.dart';

class LinsyApp extends ConsumerStatefulWidget {
  const LinsyApp({required this.appExitService, super.key});

  final AppExitService appExitService;

  @override
  ConsumerState<LinsyApp> createState() => _LinsyAppState();
}

class _LinsyAppState extends ConsumerState<LinsyApp> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();

    _lifecycleListener = AppLifecycleListener(
      // ===============================================================
      // DESKTOP EXIT REQUEST
      // ===============================================================
      onExitRequested: () async {
        await widget.appExitService.leaveCurrentRoom();

        return AppExitResponse.exit;
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    final appearance =
        ref.watch(appearanceSettingsProvider).value ??
        AppearanceSettings.defaults;

    return MaterialApp.router(
      title: 'Linsy',
      debugShowCheckedModeBanner: false,

      theme: AppThemeResolver.light(appearance),

      darkTheme: AppThemeResolver.dark(appearance),

      themeMode: appearance.themeMode,

      routerConfig: router,
    );
  }
}
