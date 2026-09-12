import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeRoomActions extends StatelessWidget {
  const HomeRoomActions({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 620;

        final create = _HomeActionCard(
          icon: Icons.add_rounded,
          title: 'Create room',
          description: 'Start a new listening room.',
          filled: true,
          onPressed: () {
            context.push('/room/create');
          },
        );

        final join = _HomeActionCard(
          icon: Icons.login_rounded,
          title: 'Join room',
          description: 'Enter a room using its code.',
          filled: false,
          onPressed: () {
            context.push('/room/join');
          },
        );

        if (!wide) {
          return Column(children: [create, const SizedBox(height: 10), join]);
        }

        return Row(
          children: [
            Expanded(child: create),
            const SizedBox(width: 12),
            Expanded(child: join),
          ],
        );
      },
    );
  }
}

class _HomeActionCard extends StatelessWidget {
  const _HomeActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.filled,
    required this.onPressed,
  });

  final IconData icon;

  final String title;
  final String description;

  final bool filled;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: filled
          ? colors.primaryContainer.withValues(alpha: 0.72)
          : colors.surfaceContainerHighest.withValues(alpha: 0.38),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: filled ? colors.primary : colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: filled
                      ? colors.onPrimary
                      : colors.onSecondaryContainer,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Icon(Icons.arrow_forward_rounded, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
