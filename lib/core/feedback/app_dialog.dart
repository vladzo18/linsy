import 'package:flutter/material.dart';

/// A shared modal for confirmations and contextual hints. Dismissal is false.
abstract final class AppDialog {
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Cancel',
    IconData icon = Icons.help_outline_rounded,
    bool destructive = false,
    Widget? detail,
  }) async {
    var resolved = false;
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            void choose(bool value) {
              if (resolved || ModalRoute.of(context)?.isCurrent != true) return;
              resolved = true;
              Navigator.pop(context, value);
            }

            final colors = Theme.of(context).colorScheme;
            final accent = destructive ? colors.error : colors.primary;
            return AlertDialog(
              constraints: const BoxConstraints(maxWidth: 440),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              icon: CircleAvatar(
                radius: 28,
                backgroundColor: accent.withValues(alpha: 0.12),
                child: Icon(icon, color: accent, size: 28),
              ),
              title: Text(title),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(message),
                    if (detail != null) ...[const SizedBox(height: 16), detail],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => choose(false),
                  child: Text(cancelLabel),
                ),
                FilledButton(
                  onPressed: () => choose(true),
                  style: destructive
                      ? FilledButton.styleFrom(
                          backgroundColor: colors.error,
                          foregroundColor: colors.onError,
                        )
                      : null,
                  child: Text(confirmLabel),
                ),
              ],
            );
          },
        ) ??
        false;
  }
}
