import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/join_room_controller.dart';
import '../controllers/join_room_state.dart';

class JoinRoomPage extends ConsumerWidget {
  const JoinRoomPage({super.key});

  Future<void> _joinRoom(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final roomId = await ref
        .read(joinRoomControllerProvider.notifier)
        .joinRoom();

    if (!context.mounted || roomId == null) {
      return;
    }

    context.push('/room/$roomId');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(joinRoomControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Join a room'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (value) {
                    ref
                        .read(joinRoomControllerProvider.notifier)
                        .setRoomId(value);
                  },
                  decoration: const InputDecoration(
                    labelText: 'Room code',
                    hintText: 'ABC123',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                if (state.errorMessage != null) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      state.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: state.canJoin
                        ? () => _joinRoom(context, ref)
                        : null,
                    child: state.status == JoinRoomStatus.loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Join'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}