import '../../../../core/platform/system_media_volume.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../player/player_volume_controller.dart';

class PlayerVolumeControl extends ConsumerWidget {
  const PlayerVolumeControl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (usesSystemMediaVolume) {
      final volume = ref.watch(systemMediaVolumeProvider).value;
      final label = volume == null
          ? 'System media volume'
          : volume == 0
          ? 'Media sound off'
          : 'Media volume ${(volume * 100).round()}%';
      return Tooltip(
        message: label,
        child: Semantics(
          label: label,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              volume == null ? Icons.volume_mute_rounded : _volumeIcon(volume),
            ),
          ),
        ),
      );
    }
    final volume = ref.watch(playerVolumeProvider);

    return MenuAnchor(
      builder: (context, controller, child) {
        return Tooltip(
          message: 'Volume ${(volume * 100).round()}%',
          child: IconButton(
            onPressed: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
            icon: Icon(_volumeIcon(volume)),
          ),
        );
      },

      // ============================================================
      // POPUP
      // ============================================================
      menuChildren: const [_VolumePopup()],
    );
  }
}

// =====================================================================
// POPUP
// =====================================================================

class _VolumePopup extends ConsumerWidget {
  const _VolumePopup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volume = ref.watch(playerVolumeProvider);

    final controller = ref.read(playerVolumeProvider.notifier);

    final percentage = (volume * 100).round();

    return SizedBox(
      width: 220,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(_volumeIcon(volume), size: 20),

                const SizedBox(width: 8),

                Expanded(
                  child: Text(
                    'Volume',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),

                Text(
                  '$percentage%',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),

            const SizedBox(height: 4),

            Slider(
              value: volume,
              min: 0,
              max: 1,
              onChanged: (value) {
                controller.setVolume(value);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// ICON
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
