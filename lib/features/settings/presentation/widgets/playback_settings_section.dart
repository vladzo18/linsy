import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/settings/playback_settings.dart';

class PlaybackSettingsSection extends ConsumerWidget {
  const PlaybackSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(playbackSettingsProvider);

    final settings = settingsState.value;

    if (settings == null) {
      return const SizedBox.shrink();
    }

    final controller = ref.read(playbackSettingsProvider.notifier);

    final volume = settings.defaultVolume;

    final percentage = (volume * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Playback',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),

        const SizedBox(height: 10),

        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(_playbackVolumeIcon(volume), size: 22),

                    const SizedBox(width: 12),

                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Default player volume'),

                          SizedBox(height: 2),

                          Text(
                            'Used when the player starts.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),

                    Text(
                      '$percentage%',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                Slider(
                  value: volume,
                  min: 0,
                  max: 1,

                  onChanged: (value) {
                    controller.setDefaultVolume(value);
                  },

                  onChangeEnd: (value) async {
                    try {
                      await controller.saveDefaultVolume(value);
                    } catch (error) {
                      if (!context.mounted) {
                        return;
                      }

                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            content: Text(
                              'Failed to save playback settings: $error',
                            ),
                          ),
                        );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

IconData _playbackVolumeIcon(double volume) {
  if (volume <= 0) {
    return Icons.volume_off_rounded;
  }

  if (volume < 0.5) {
    return Icons.volume_down_rounded;
  }

  return Icons.volume_up_rounded;
}
