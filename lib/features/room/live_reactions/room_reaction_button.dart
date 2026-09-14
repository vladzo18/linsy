import 'package:flutter/material.dart';
import 'room_live_reaction_service.dart';

class RoomReactionButton extends StatelessWidget {
  const RoomReactionButton({
    required this.compact,
    required this.onPressed,
    this.open = false,
    super.key,
  });
  final bool compact;
  final bool open;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: SizedBox(
      width: compact ? 54 : 104,
      child: Center(
        child: IconButton(
          tooltip: open ? 'Close reactions' : 'React',
          onPressed: onPressed,
          icon: Icon(open ? Icons.close_rounded : Icons.add_reaction_outlined),
        ),
      ),
    ),
  );
}

class RoomReactionPicker extends StatelessWidget {
  const RoomReactionPicker({required this.onSelected, super.key});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 270,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 270),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final reaction in roomLiveReactionDefinitions)
                Tooltip(
                  message: reaction.label,
                  child: InkResponse(
                    radius: 24,
                    onTap: () {
                      onSelected(reaction.id);
                    },
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: Text(
                          reaction.emoji,
                          style: const TextStyle(fontSize: 27, height: 1),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
