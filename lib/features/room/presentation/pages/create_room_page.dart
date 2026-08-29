import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/create_room_controller.dart';
import '../controllers/create_room_state.dart';

class CreateRoomPage extends ConsumerWidget {
  const CreateRoomPage({super.key});

  Future<void> _createRoom(WidgetRef ref) async {
    await ref
        .read(createRoomControllerProvider.notifier)
        .createRoom();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(createRoomControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create a room'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 500,
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  onChanged: (value) {
                    ref
                        .read(
                          createRoomControllerProvider.notifier,
                        )
                        .setName(value);
                  },
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Room name',
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
                        color: Theme.of(context)
                            .colorScheme
                            .error,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: state.canCreate
                        ? () => _createRoom(ref)
                        : null,
                    child: state.status ==
                            CreateRoomStatus.loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Create'),
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