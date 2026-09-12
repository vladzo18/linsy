import 'package:flutter/material.dart';

import 'message_formatters.dart';
import 'message_reaction_chips.dart';

class MessageReactionTimeRow extends StatelessWidget {
  const MessageReactionTimeRow({
    super.key,
    required this.summaries,
    required this.maxReactionWidth,
    required this.dateTime,
    required this.textColor,
    required this.onToggleReaction,
  });

  final List<MessageReactionSummary> summaries;

  final double maxReactionWidth;

  final DateTime dateTime;

  final Color textColor;

  final Future<void> Function(String reaction) onToggleReaction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.end,

      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxReactionWidth),

          child: Wrap(
            alignment: WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.center,

            spacing: 5,
            runSpacing: 4,

            children: [
              for (final summary in summaries)
                MessageReactionChip(
                  summary: summary,
                  selected: summary.selectedByMe,

                  onPressed: () async {
                    await onToggleReaction(summary.reactionId);
                  },
                ),
            ],
          ),
        ),

        const Spacer(),

        const SizedBox(width: 10),

        Padding(
          padding: const EdgeInsets.only(bottom: 2),

          child: Text(
            formatMessageTime(dateTime),

            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor.withValues(alpha: 0.55),
            ),
          ),
        ),
      ],
    );
  }
}

// TIME WITHOUT REACTIONS

class MessageTime extends StatelessWidget {
  const MessageTime({
    super.key,
    required this.dateTime,
    required this.textColor,
  });

  final DateTime dateTime;

  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        formatMessageTime(dateTime),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: textColor.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}
