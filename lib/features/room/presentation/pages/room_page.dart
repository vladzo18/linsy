import 'package:flutter/material.dart';

class RoomPage extends StatelessWidget {
  final String? roomId;

  const RoomPage({
    super.key, 
    required this.roomId
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Room : $roomId'),
      ),
      body: const Center(
        child: Text('Here will be joint listening and chat'),
      ),
    );
  }
}