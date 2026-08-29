import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme_resolver.dart';
import '../../../../core/settings/appearance_settings.dart';

class CustomThemePage extends ConsumerStatefulWidget {
  const CustomThemePage({super.key});

  @override
  ConsumerState<CustomThemePage> createState() => _CustomThemePageState();
}

enum _EditingThemeColor { main, accent }

class _CustomThemePageState extends ConsumerState<CustomThemePage> {
  static const double _desktopBreakpoint = 900;

  late final TextEditingController _nameController;

  late Color _seedColor;
  late Color _accentColor;

  late double _backgroundStrength;

  _EditingThemeColor _editingColor = _EditingThemeColor.main;

  Brightness _previewBrightness = Brightness.light;

  bool _saving = false;

  // ===================================================================
  // INIT
  // ===================================================================

  @override
  void initState() {
    super.initState();

    final settings =
        ref.read(appearanceSettingsProvider).value ??
        AppearanceSettings.defaults;

    _nameController = TextEditingController(text: settings.customThemeName);

    _seedColor = settings.customSeedColor;
    _accentColor = settings.customAccentColor;

    _backgroundStrength = settings.customBackgroundStrength;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _previewBrightness = Theme.of(context).brightness;
      });
    });
  }

  // ===================================================================
  // DISPOSE
  // ===================================================================

  @override
  void dispose() {
    _nameController.dispose();

    super.dispose();
  }

  // ===================================================================
  // GETTERS
  // ===================================================================

  Color get _currentColor {
    return _editingColor == _EditingThemeColor.main ? _seedColor : _accentColor;
  }

  // ===================================================================
  // SAVE
  // ===================================================================

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await ref
          .read(appearanceSettingsProvider.notifier)
          .saveCustomTheme(
            name: _nameController.text,
            seedColor: _seedColor,
            accentColor: _accentColor,
            backgroundStrength: _backgroundStrength,
          );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Failed to save theme: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // ===================================================================
  // BUILD
  // ===================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom theme'),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: const Text('Save'),
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= _desktopBreakpoint;

            if (isDesktop) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1500),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // =============================================
                        // LEFT — PREVIEW
                        // =============================================
                        Expanded(flex: 6, child: _buildPreviewPane(context)),

                        const SizedBox(width: 28),

                        // =============================================
                        // RIGHT — SETTINGS
                        // =============================================
                        Expanded(flex: 5, child: _buildSettingsPane(context)),
                      ],
                    ),
                  ),
                ),
              );
            }

            // =======================================================
            // MOBILE
            // =======================================================

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildPreviewPane(context),

                  const SizedBox(height: 32),

                  _buildSettingsPane(context),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ===================================================================
  // PREVIEW PANE
  // ===================================================================

  Widget _buildPreviewPane(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Live preview',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    'Updates instantly as you edit the theme.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 16),

            SegmentedButton<Brightness>(
              segments: const [
                ButtonSegment(
                  value: Brightness.light,
                  icon: Icon(Icons.light_mode_outlined),
                ),
                ButtonSegment(
                  value: Brightness.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                ),
              ],
              selected: {_previewBrightness},
              onSelectionChanged: (selection) {
                setState(() {
                  _previewBrightness = selection.first;
                });
              },
            ),
          ],
        ),

        const SizedBox(height: 18),

        _ThemePreview(
          seedColor: _seedColor,
          accentColor: _accentColor,
          backgroundStrength: _backgroundStrength,
          brightness: _previewBrightness,
        ),
      ],
    );
  }

  // ===================================================================
  // SETTINGS PANE
  // ===================================================================

  Widget _buildSettingsPane(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Theme settings',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 4),

        Text(
          'Choose colors and customize how your theme looks.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),

        const SizedBox(height: 22),

        // ===========================================================
        // NAME
        // ===========================================================
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Theme name',
            prefixIcon: Icon(Icons.label_outline_rounded),
            border: OutlineInputBorder(),
          ),
        ),

        const SizedBox(height: 22),

        // ===========================================================
        // COLORS
        // ===========================================================
        Text(
          'Colors',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),

        const SizedBox(height: 10),

        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ===================================================
                // MAIN / ACCENT
                // ===================================================
                SegmentedButton<_EditingThemeColor>(
                  segments: [
                    ButtonSegment(
                      value: _EditingThemeColor.main,
                      icon: _ColorDot(color: _seedColor),
                      label: const Text('Main'),
                    ),
                    ButtonSegment(
                      value: _EditingThemeColor.accent,
                      icon: _ColorDot(color: _accentColor),
                      label: const Text('Accent'),
                    ),
                  ],
                  selected: {_editingColor},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _editingColor = selection.first;
                    });
                  },
                ),

                const SizedBox(height: 18),

                // ===================================================
                // CURRENT COLOR
                // ===================================================
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _editingColor == _EditingThemeColor.main
                            ? 'Main color'
                            : 'Accent color',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),

                    IconButton(
                      tooltip: 'Swap colors',
                      onPressed: () {
                        setState(() {
                          final oldMain = _seedColor;

                          _seedColor = _accentColor;

                          _accentColor = oldMain;
                        });
                      },
                      icon: const Icon(Icons.swap_horiz_rounded),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // ===================================================
                // PICKER
                // ===================================================
                LayoutBuilder(
                  builder: (context, constraints) {
                    return ColorPicker(
                      key: ValueKey(_editingColor),
                      pickerColor: _currentColor,
                      onColorChanged: (color) {
                        setState(() {
                          if (_editingColor == _EditingThemeColor.main) {
                            _seedColor = color;
                          } else {
                            _accentColor = color;
                          }
                        });
                      },

                      enableAlpha: false,

                      displayThumbColor: false,

                      paletteType: PaletteType.hsvWithHue,

                      portraitOnly: true,

                      colorPickerWidth: 300,

                      pickerAreaHeightPercent: 0.55,

                      // Убираем RGB / HSV / HSL подписи.
                      labelTypes: const [],

                      // Убираем ручной HEX ввод.
                      hexInputBar: false,
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 22),

        // ===========================================================
        // BACKGROUND
        // ===========================================================
        Text(
          'Background',
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
              children: [
                Row(
                  children: [
                    const Icon(Icons.format_color_fill_rounded),

                    const SizedBox(width: 12),

                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Background tint'),
                          SizedBox(height: 2),
                          Text(
                            'How much the main color affects surfaces.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),

                    Text(
                      '${(_backgroundStrength * 100).round()}%',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                Slider(
                  value: _backgroundStrength,
                  min: 0,
                  max: 1,
                  divisions: 20,
                  onChanged: (value) {
                    setState(() {
                      _backgroundStrength = value;
                    });
                  },
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Text('Neutral', style: TextStyle(fontSize: 12)),
                      Spacer(),
                      Text('Tinted', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ===========================================================
        // SAVE
        // ===========================================================
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded),
          label: const Text('Save theme'),
        ),
      ],
    );
  }
}

// =====================================================================
// PREVIEW
// =====================================================================

class _ThemePreview extends StatelessWidget {
  const _ThemePreview({
    required this.seedColor,
    required this.accentColor,
    required this.backgroundStrength,
    required this.brightness,
  });

  final Color seedColor;
  final Color accentColor;

  final double backgroundStrength;

  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeResolver.customPreview(
      seedColor: seedColor,
      accentColor: accentColor,
      backgroundStrength: backgroundStrength,
      brightness: brightness,
    );

    return Theme(
      data: theme,
      child: Builder(
        builder: (context) {
          final colors = Theme.of(context).colorScheme;

          return Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ===================================================
                // APP BAR
                // ===================================================
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                  child: Row(
                    children: [
                      const Icon(Icons.music_note_rounded),

                      const SizedBox(width: 8),

                      Text(
                        'Linsy',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const Spacer(),

                      const Icon(Icons.settings_outlined),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // ===================================================
                // PAGE CONTENT
                // ===================================================
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Welcome back',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        'Create a room or join one with your friends.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),

                      const SizedBox(height: 18),

                      // =============================================
                      // MAIN COLORS
                      // =============================================
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Create room'),
                            ),
                          ),

                          const SizedBox(width: 10),

                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.login_rounded),
                              label: const Text('Join room'),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // =============================================
                      // ACCENT COLORS
                      // =============================================
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                            avatar: Icon(
                              Icons.star_rounded,
                              size: 17,
                              color: colors.onSecondaryContainer,
                            ),
                            label: const Text('Accent'),
                            backgroundColor: colors.secondaryContainer,
                            side: BorderSide.none,
                          ),

                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: colors.secondary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Moderator',
                              style: TextStyle(
                                color: colors.onSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // =============================================
                      // ROOM CARD
                      // =============================================
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'My room',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),

                              const SizedBox(height: 8),

                              Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: colors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),

                                  const SizedBox(width: 8),

                                  const Text('Code: 4FB04F'),

                                  const SizedBox(width: 6),

                                  const Icon(Icons.copy_rounded, size: 17),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // No fake player slider here.
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () {},
                                      child: const Text('Rejoin'),
                                    ),
                                  ),

                                  const SizedBox(width: 10),

                                  Expanded(
                                    child: FilledButton.tonal(
                                      onPressed: () {},
                                      child: const Text('Delete'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // =============================================
                      // SETTINGS EXAMPLE
                      // =============================================
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.notifications_outlined,
                                color: colors.primary,
                              ),

                              const SizedBox(width: 12),

                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('UI sounds'),
                                    SizedBox(height: 2),
                                    Text(
                                      'Play notification sounds',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),

                              Switch(value: true, onChanged: (_) {}),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // =============================================
                      // MORE UI EXAMPLES
                      // =============================================
                      Row(
                        children: [
                          Expanded(
                            child: Card(
                              margin: EdgeInsets.zero,
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      color: colors.primary,
                                    ),
                                    const SizedBox(width: 10),
                                    const Expanded(child: Text('Chat')),
                                    Badge(
                                      label: const Text('3'),
                                      child: const SizedBox(
                                        width: 1,
                                        height: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 10),

                          Expanded(
                            child: Card(
                              margin: EdgeInsets.zero,
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.queue_music_rounded,
                                      color: colors.secondary,
                                    ),
                                    const SizedBox(width: 10),
                                    const Expanded(child: Text('Queue')),
                                    const Icon(
                                      Icons.drag_handle_rounded,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// =====================================================================
// HELPERS
// =====================================================================

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
