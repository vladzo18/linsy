import 'package:flutter/material.dart';

import '../reactions/reaction_catalog.dart';

class MessageReactionVisual extends StatelessWidget {
  const MessageReactionVisual({
    super.key,
    required this.reactionId,
    required this.size,
  });

  final String reactionId;

  final double size;

  @override
  Widget build(BuildContext context) {
    final definition = ReactionCatalog.find(reactionId);

    final assetPath = definition?.assetPath;

    if (assetPath != null) {
      return Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Text('❔', style: TextStyle(fontSize: size));
        },
      );
    }

    return Text(
      definition?.emoji ?? '❔',
      style: TextStyle(fontSize: size, height: 1),
    );
  }
}
