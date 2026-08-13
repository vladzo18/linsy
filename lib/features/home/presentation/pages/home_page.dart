import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Linsy'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Listen to your favorite music with Linsy together!',
              style: TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                context.push('/room/create');
              },
              child: const Text('Create a room'),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                context.push('/room/join');
              },
              child: const Text('Join a room'),
            ),
          ],
        ),
      ),
    );
  }
}