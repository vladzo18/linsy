import 'package:flutter/material.dart';

class HomeWelcomeSection extends StatelessWidget {
  const HomeWelcomeSection({super.key, required this.userName});

  final String? userName;

  @override
  Widget build(BuildContext context) {
    final cleanName = userName?.trim();

    final greeting = cleanName == null || cleanName.isEmpty
        ? 'Welcome back'
        : 'Welcome back, $cleanName';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'Listen together, wherever you are.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
