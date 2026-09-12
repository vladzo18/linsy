import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:linsy/core/settings/appearance_settings.dart';

import '../pages/custom_theme_page.dart';

class AppearanceSettingsSection extends ConsumerWidget {
  const AppearanceSettingsSection({super.key});

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
              // LIGHT / DARK / SYSTEM
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
          constraints: const BoxConstraints(minHeight: 86),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
