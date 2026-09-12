import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme_resolver.dart';

class CustomThemePreview extends StatelessWidget {
  const CustomThemePreview({
    super.key,
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
                // APP BAR
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

                // PAGE CONTENT
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

                      // MAIN COLORS
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

                      // ACCENT COLORS
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

                      // ROOM CARD
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

                      // SETTINGS EXAMPLE
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

                      // MORE UI EXAMPLES
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
