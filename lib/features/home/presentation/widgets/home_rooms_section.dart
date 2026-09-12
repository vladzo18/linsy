import 'package:flutter/material.dart';

import '../controllers/home_state.dart';

import 'home_room_card.dart';

class HomeRoomsSection extends StatelessWidget {
  const HomeRoomsSection({super.key, required this.state});

  final HomeState state;

  @override
  Widget build(BuildContext context) {
    if (state.status == HomeStatus.error) {
      return HomeErrorCard(message: state.errorMessage, onRetry: () {});
    }

    if (state.rooms.isEmpty) {
      return const HomeEmptyRoomsCard();
    }

    return Column(
      children: [
        for (var i = 0; i < state.rooms.length; i++) ...[
          HomeRoomCard(item: state.rooms[i]),
          if (i != state.rooms.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

// ROOM CARD

class HomeRoomsLoading extends StatelessWidget {
  const HomeRoomsLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

// EMPTY

class HomeEmptyRoomsCard extends StatelessWidget {
  const HomeEmptyRoomsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          children: [
            Icon(
              Icons.meeting_room_outlined,
              size: 44,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'No rooms yet.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 5),
            Text(
              'Create a room or join one to see it here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ERROR

class HomeErrorCard extends StatelessWidget {
  const HomeErrorCard({super.key, this.message, required this.onRetry});

  final String? message;

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 42,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 10),
            Text(
              message ?? 'Failed to load your rooms.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
