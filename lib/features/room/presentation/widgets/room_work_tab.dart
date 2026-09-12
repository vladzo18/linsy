import 'package:flutter/material.dart';

class RoomWorkTab extends StatelessWidget {
  const RoomWorkTab({
    super.key,
    required this.icon,
    required this.label,
    required this.showNew,
  });

  final IconData icon;
  final String label;
  final bool showNew;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ICON + NEW DOT
          SizedBox(
            width: 30,
            height: 24,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(child: Center(child: Icon(icon, size: 22))),

                if (showNew)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colorScheme.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 2),

          Text(label),
        ],
      ),
    );
  }
}
