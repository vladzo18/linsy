import '../../../../core/platform/system_media_volume.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:linsy/features/settings/presentation/wingets/profile_settings_section.dart';

import '../../../../core/settings/app_sound_settings.dart';

import '../widgets/appearance_settings_section.dart';
import '../widgets/playback_settings_section.dart';
import '../wingets/ui_sound_settings_section.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final soundSettings = ref.watch(appSoundSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),

      body: SafeArea(
        child: soundSettings.when(
          loading: () => const Center(child: CircularProgressIndicator()),

          error: (error, stackTrace) => _SettingsError(
            error: error,
            onRetry: () {
              ref.invalidate(appSoundSettingsProvider);
            },
          ),

          data: (settings) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              children:
                  [
                        const ProfileSettingsSection(),

                        const SizedBox(height: 24),

                        const AppearanceSettingsSection(),

                        const SizedBox(height: 24),

                        if (!usesSystemMediaVolume) ...[
                          const PlaybackSettingsSection(),
                          const SizedBox(height: 24),
                        ],

                        const UiSoundSettingsSection(),
                      ]
                      .map(
                        (child) => Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 720),
                            child: SizedBox(
                              width: double.infinity,
                              child: child,
                            ),
                          ),
                        ),
                      )
                      .toList(),
            );
          },
        ),
      ),
    );
  }
}

// ERROR

class _SettingsError extends StatelessWidget {
  const _SettingsError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 42,
              color: Theme.of(context).colorScheme.error,
            ),

            const SizedBox(height: 12),

            const Text('Failed to load settings.'),

            const SizedBox(height: 4),

            Text(
              '$error',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),

            const SizedBox(height: 14),

            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
