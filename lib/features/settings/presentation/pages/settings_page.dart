import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:linsy/core/settings/appearance_settings.dart';
import 'package:linsy/core/settings/playback_settings.dart';
import 'package:linsy/features/settings/presentation/wingets/profile_settings_section.dart';
import 'package:linsy/features/settings/presentation/wingets/ui_sound_settings_section.dart';

import 'custom_theme_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),

      body: SafeArea(
        // =============================================================
        // ВАЖНО:
        //
        // ListView занимает всю ширину окна.
        //
        // Поэтому desktop scrollbar теперь располагается
        // у правого края окна, а не у края контента шириной 720.
        // =============================================================
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ===============================================
                    // PROFILE
                    // ===============================================
                    ProfileSettingsSection(),

                    SizedBox(height: 24),

                    // ===============================================
                    // APPEARANCE
                    // ===============================================
                    _AppearanceSection(),

                    SizedBox(height: 24),

                    // ===============================================
                    // PLAYBACK
                    // ===============================================
                    _PlaybackSection(),

                    SizedBox(height: 24),

                    // ===============================================
                    // UI SOUNDS
                    // ===============================================
                    UiSoundSettingsSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// APPEARANCE
// =====================================================================

class _AppearanceSection extends ConsumerWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearanceState = ref.watch(appearanceSettingsProvider);

    final appearance = appearanceState.value;

    if (appearance == null) {
      return const SizedBox.shrink();
    }

    final controller = ref.read(appearanceSettingsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Appearance',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),

        const SizedBox(height: 10),

        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              // =====================================================
              // LIGHT / DARK / SYSTEM
              // =====================================================
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    const Icon(Icons.brightness_6_outlined),

                    const SizedBox(width: 12),

                    const Expanded(child: Text('Mode')),

                    SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.computer_rounded),
                        ),

                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode_outlined),
                        ),

                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode_outlined),
                        ),
                      ],

                      selected: {appearance.themeMode},

                      onSelectionChanged: (selection) {
                        controller.setThemeMode(selection.first);
                      },
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // =====================================================
              // THEMES
              // =====================================================
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Theme'),

                    const SizedBox(height: 12),

                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isCompact = constraints.maxWidth < 520;

                        const spacing = 8.0;

                        final itemWidth = isCompact
                            ? (constraints.maxWidth - spacing * 2) / 3
                            : 108.0;

                        return Wrap(
                          alignment: WrapAlignment.center,
                          spacing: spacing,
                          runSpacing: spacing,
                          children: [
                            // =======================================
                            // LINSY
                            // =======================================
                            SizedBox(
                              width: itemWidth,
                              child: _ThemeChoice(
                                name: 'Linsy',
                                color: const Color(0xFF7655A6),
                                selected:
                                    appearance.preset == AppThemePreset.linsy,
                                onTap: () {
                                  controller.setPreset(AppThemePreset.linsy);
                                },
                              ),
                            ),

                            // =======================================
                            // LAVENDER
                            // =======================================
                            SizedBox(
                              width: itemWidth,
                              child: _ThemeChoice(
                                name: 'Lavender',
                                color: const Color(0xFF9A7BEF),
                                selected:
                                    appearance.preset ==
                                    AppThemePreset.lavender,
                                onTap: () {
                                  controller.setPreset(AppThemePreset.lavender);
                                },
                              ),
                            ),

                            // =======================================
                            // ROSE
                            // =======================================
                            SizedBox(
                              width: itemWidth,
                              child: _ThemeChoice(
                                name: 'Rose',
                                color: const Color(0xFFE05D8A),
                                selected:
                                    appearance.preset == AppThemePreset.rose,
                                onTap: () {
                                  controller.setPreset(AppThemePreset.rose);
                                },
                              ),
                            ),

                            // =======================================
                            // OCEAN
                            // =======================================
                            SizedBox(
                              width: itemWidth,
                              child: _ThemeChoice(
                                name: 'Ocean',
                                color: const Color(0xFF3E82D7),
                                selected:
                                    appearance.preset == AppThemePreset.ocean,
                                onTap: () {
                                  controller.setPreset(AppThemePreset.ocean);
                                },
                              ),
                            ),

                            // =======================================
                            // CUSTOM
                            // =======================================
                            SizedBox(
                              width: itemWidth,
                              child: _ThemeChoice(
                                name: appearance.customThemeName,
                                color: appearance.customSeedColor,
                                selected:
                                    appearance.preset == AppThemePreset.custom,
                                custom: true,
                                onTap: () {
                                  controller.setPreset(AppThemePreset.custom);
                                },
                                onEdit: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (context) =>
                                          const CustomThemePage(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =====================================================================
// THEME CHOICE
// =====================================================================

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({
    required this.name,
    required this.color,
    required this.selected,
    required this.onTap,
    this.onEdit,
    this.custom = false,
  });

  final String name;

  final Color color;

  final bool selected;

  final VoidCallback onTap;

  final VoidCallback? onEdit;

  final bool custom;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 78,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),

            color: selected
                ? colors.primaryContainer.withValues(alpha: 0.45)
                : colors.surfaceContainerLow,

            border: Border.all(
              color: selected ? colors.primary : Colors.transparent,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: selected
                          ? const Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: Colors.white,
                            )
                          : null,
                    ),

                    const SizedBox(height: 6),

                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),

              if (custom && onEdit != null)
                Positioned(
                  top: -5,
                  right: -5,
                  child: IconButton(
                    tooltip: 'Edit custom theme',
                    onPressed: onEdit,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.edit_rounded, size: 15),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// PLAYBACK
// =====================================================================

class _PlaybackSection extends ConsumerWidget {
  const _PlaybackSection();

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

// =====================================================================
// PLAYBACK VOLUME ICON
// =====================================================================

IconData _playbackVolumeIcon(double volume) {
  if (volume <= 0) {
    return Icons.volume_off_rounded;
  }

  if (volume < 0.5) {
    return Icons.volume_down_rounded;
  }

  return Icons.volume_up_rounded;
}
