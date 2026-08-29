import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/room_message.dart';

class RoomMessageComposer extends StatefulWidget {
  const RoomMessageComposer({
    required this.onSend,
    required this.replyingTo,
    required this.onCancelReply,
    super.key,
  });

  final Future<void> Function(String message) onSend;

  final RoomMessage? replyingTo;

  final VoidCallback onCancelReply;

  @override
  State<RoomMessageComposer> createState() => _RoomMessageComposerState();
}

class _RoomMessageComposerState extends State<RoomMessageComposer> {
  final TextEditingController _textController = TextEditingController();

  final FocusNode _focusNode = FocusNode();

  bool _sending = false;

  // ===================================================================
  // STATE
  // ===================================================================

  bool get _canSend {
    return !_sending && _textController.text.trim().isNotEmpty;
  }

  // ===================================================================
  // INIT
  // ===================================================================

  @override
  void initState() {
    super.initState();

    _textController.addListener(_handleTextChanged);
  }

  // ===================================================================
  // UPDATE
  // ===================================================================

  @override
  void didUpdateWidget(covariant RoomMessageComposer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Пользователь нажал Reply —
    // сразу переводим фокус в composer.

    if (widget.replyingTo?.id != oldWidget.replyingTo?.id) {
      if (widget.replyingTo != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }

          _focusNode.requestFocus();
        });
      }
    }
  }

  // ===================================================================
  // DISPOSE
  // ===================================================================

  @override
  void dispose() {
    _textController.removeListener(_handleTextChanged);

    _textController.dispose();

    _focusNode.dispose();

    super.dispose();
  }

  // ===================================================================
  // TEXT
  // ===================================================================

  void _handleTextChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  // ===================================================================
  // NEW LINE
  // ===================================================================

  void _insertNewLine() {
    if (_sending) {
      return;
    }

    final value = _textController.value;

    final text = value.text;

    // Соблюдаем тот же maxLength,
    // который указан у TextField.
    if (text.length >= 4000) {
      return;
    }

    var start = value.selection.start;

    var end = value.selection.end;

    // Иногда selection может быть -1,
    // например после некоторых изменений focus.
    if (start < 0 || end < 0) {
      start = text.length;
      end = text.length;
    }

    final newText = text.replaceRange(start, end, '\n');

    final newCursorPosition = start + 1;

    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPosition),
    );
  }

  // ===================================================================
  // SEND
  // ===================================================================

  Future<void> _send() async {
    if (!_canSend) {
      return;
    }

    final content = _textController.text.trim();

    if (content.isEmpty) {
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      await widget.onSend(content);

      if (!mounted) {
        return;
      }

      _textController.clear();

      _focusNode.requestFocus();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Failed to send message: $error')),
        );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  // ===================================================================
  // BUILD
  // ===================================================================

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ===============================================================
        // REPLYING TO
        // ===============================================================
        if (widget.replyingTo != null) ...[
          _ReplyingToBar(
            message: widget.replyingTo!,
            onCancel: widget.onCancelReply,
          ),

          const SizedBox(height: 8),
        ],

        // ===============================================================
        // INPUT
        // ===============================================================
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              // =========================================================
              // DESKTOP KEYBOARD SHORTCUTS
              // =========================================================
              //
              // Enter
              //   -> send
              //
              // Shift + Enter
              //   -> newline
              //
              // Escape
              //   -> cancel reply
              //
              // SingleActivator различает модификаторы,
              // поэтому Shift+Enter больше не попадает
              // в обработчик обычного Enter.
              // =========================================================
              child: CallbackShortcuts(
                bindings: {
                  // =====================================================
                  // ENTER = SEND
                  // =====================================================
                  const SingleActivator(LogicalKeyboardKey.enter): () {
                    if (_canSend) {
                      _send();
                    }
                  },

                  // =====================================================
                  // SHIFT + ENTER = NEW LINE
                  // =====================================================
                  const SingleActivator(LogicalKeyboardKey.enter, shift: true):
                      _insertNewLine,

                  // =====================================================
                  // ESCAPE = CANCEL REPLY
                  // =====================================================
                  const SingleActivator(LogicalKeyboardKey.escape): () {
                    if (widget.replyingTo != null) {
                      widget.onCancelReply();
                    }
                  },
                },

                child: TextField(
                  controller: _textController,

                  focusNode: _focusNode,

                  enabled: !_sending,

                  minLines: 1,

                  maxLines: 5,

                  maxLength: 4000,

                  // ВАЖНО:
                  //
                  // Больше не ставим TextInputAction.send.
                  //
                  // Иначе EditableText сам пытается
                  // интерпретировать Enter как submit.
                  textInputAction: TextInputAction.newline,

                  keyboardType: TextInputType.multiline,

                  decoration: const InputDecoration(
                    hintText: 'Message...',

                    border: OutlineInputBorder(),

                    counterText: '',
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // ===========================================================
            // SEND BUTTON
            // ===========================================================
            IconButton.filled(
              tooltip: 'Send message',

              onPressed: _canSend ? _send : null,

              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ],
    );
  }
}

// =====================================================================
// REPLYING TO BAR
// =====================================================================

class _ReplyingToBar extends StatelessWidget {
  const _ReplyingToBar({required this.message, required this.onCancel});

  final RoomMessage message;

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.only(left: 12, top: 8, bottom: 8, right: 4),

      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,

        borderRadius: BorderRadius.circular(10),

        border: Border(left: BorderSide(color: colors.primary, width: 3)),
      ),

      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to ${message.userName}',

                  maxLines: 1,

                  overflow: TextOverflow.ellipsis,

                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.primary,

                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  message.content,

                  maxLines: 1,

                  overflow: TextOverflow.ellipsis,

                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),

          IconButton(
            tooltip: 'Cancel reply',

            visualDensity: VisualDensity.compact,

            onPressed: onCancel,

            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }
}
