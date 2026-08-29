import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:linsy/core/settings/app_sound_settings.dart';
import 'package:linsy/core/sounds/ui_sound.dart';
import 'package:linsy/core/sounds/ui_sound_provider.dart';

class UiSoundSettingsSection extends ConsumerWidget {
  const UiSoundSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(appSoundSettingsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // =============================================================
        // TITLE
        // =============================================================
        Text(
          'Sounds',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),

        const SizedBox(height: 10),

        // =============================================================
        // STATE
        // =============================================================
        settingsState.when(
          loading: () => const _SoundSettingsLoading(),

          error: (error, stackTrace) => _SoundSettingsError(
            error: error,
            onRetry: () {
              ref.invalidate(appSoundSettingsProvider);
            },
          ),

          data: (settings) {
            final controller = ref.read(appSoundSettingsProvider.notifier);

            return Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // ===================================================
                  // ENABLED
                  // ===================================================
                  SwitchListTile(
                    secondary: const Icon(Icons.notifications_active_outlined),

                    title: const Text('UI sounds'),

                    subtitle: const Text(
                      'Play sounds for messages, requests and room activity.',
                    ),

                    value: settings.enabled,

                    onChanged: (enabled) {
                      unawaited(controller.setEnabled(enabled));
                    },
                  ),

                  const Divider(height: 1),

                  // ===================================================
                  // VOLUME
                  // ===================================================
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(_volumeIcon(settings.volume), size: 22),

                            const SizedBox(width: 12),

                            const Expanded(child: Text('Notification volume')),

                            Text(
                              '${(settings.volume * 100).round()}%',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ],
                        ),

                        const SizedBox(height: 4),

                        Slider(
                          value: settings.volume,
                          min: 0,
                          max: 1,

                          onChanged: settings.enabled
                              ? controller.setVolume
                              : null,

                          onChangeEnd: settings.enabled
                              ? (value) {
                                  unawaited(controller.saveVolume(value));
                                }
                              : null,
                        ),

                        const SizedBox(height: 4),

                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton.tonalIcon(
                            onPressed: settings.enabled
                                ? () async {
                                    final service = ref.read(
                                      uiSoundServiceProvider,
                                    );

                                    service.setEnabled(settings.enabled);

                                    service.setVolume(settings.volume);

                                    await service.play(UiSound.message);
                                  }
                                : null,

                            icon: const Icon(
                              Icons.volume_up_outlined,
                              size: 19,
                            ),

                            label: const Text('Test sound'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

// =====================================================================
// LOADING
// =====================================================================

class _SoundSettingsLoading extends StatelessWidget {
  const _SoundSettingsLoading();

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

// =====================================================================
// ERROR
// =====================================================================

class _SoundSettingsError extends StatelessWidget {
  const _SoundSettingsError({required this.error, required this.onRetry});

  final Object error;

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              size: 36,
              color: Theme.of(context).colorScheme.error,
            ),

            const SizedBox(height: 10),

            const Text('Failed to load sound settings.'),

            const SizedBox(height: 4),

            Text(
              '$error',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),

            const SizedBox(height: 12),

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

// =====================================================================
// VOLUME ICON
// =====================================================================

IconData _volumeIcon(double volume) {
  if (volume <= 0) {
    return Icons.volume_off_rounded;
  }

  if (volume < 0.5) {
    return Icons.volume_down_rounded;
  }

  return Icons.volume_up_rounded;
}
