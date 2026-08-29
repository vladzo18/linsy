import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/domain/models/app_user.dart';
import '../../../../auth/presentation/controllers/auth_controller.dart';

import '../../domain/models/room_message.dart';
import '../../domain/models/room_message_reaction.dart';
import '../controllers/room_chat_controller.dart';
import '../controllers/room_reaction_controller.dart';
import 'room_message_bubble.dart';
import 'room_message_composer.dart';

class RoomChat extends ConsumerStatefulWidget {
  const RoomChat({
    required this.roomId,
    this.height,
    this.embedded = false,
    super.key,
  });

  final String roomId;
  final double? height;

  /// When true, the chat is rendered as tab content:
  /// no outer Card and no duplicate "Chat" header.
  final bool embedded;

  @override
  ConsumerState<RoomChat> createState() => _RoomChatState();
}

class _RoomChatState extends ConsumerState<RoomChat>
    with AutomaticKeepAliveClientMixin<RoomChat> {
  final ScrollController _scrollController = ScrollController();

  // ===================================================
  // PROFILE CACHE
  // ===================================================
  //
  // Храним последний известный актуальный профиль.
  //
  // Если пользователь вышел из комнаты,
  // RoomState больше его не содержит, но чат
  // продолжает использовать последнее известное
  // имя и аватар.
  // ===================================================

  final Map<String, AppUser> _profileCache = {};

  RoomMessage? _replyingTo;

  bool _loadingOlder = false;
  bool _hasMoreOlder = true;

  @override
  bool get wantKeepAlive => true;

  // ===================================================
  // INIT
  // ===================================================

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(_handleScroll);
  }

  // ===================================================
  // DISPOSE
  // ===================================================

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);

    _scrollController.dispose();

    super.dispose();
  }

  // ===================================================
  // REPLY
  // ===================================================

  void _startReply(RoomMessage message) {
    setState(() {
      _replyingTo = message;
    });
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
    });
  }

  // ===================================================
  // AUTO SCROLL
  // ===================================================

  bool get _isNearBottom {
    if (!_scrollController.hasClients) {
      return true;
    }

    final position = _scrollController.position;

    final distance = position.maxScrollExtent - position.pixels;

    return distance < 160;
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      final target = _scrollController.position.maxScrollExtent;

      if (!animate) {
        _scrollController.jumpTo(target);

        return;
      }

      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  // ===================================================
  // PAGINATION
  // ===================================================

  void _handleScroll() {
    if (!_scrollController.hasClients || _loadingOlder || !_hasMoreOlder) {
      return;
    }

    if (_scrollController.position.pixels > 120) {
      return;
    }

    unawaited(_loadOlder());
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || !_hasMoreOlder || !_scrollController.hasClients) {
      return;
    }

    _loadingOlder = true;

    final position = _scrollController.position;

    final oldMaxExtent = position.maxScrollExtent;

    final oldPixels = position.pixels;

    try {
      final loaded = await ref
          .read(roomChatControllerProvider(widget.roomId).notifier)
          .loadOlder();

      if (!loaded) {
        _hasMoreOlder = false;

        return;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) {
          return;
        }

        final newMaxExtent = _scrollController.position.maxScrollExtent;

        final addedHeight = newMaxExtent - oldMaxExtent;

        final target = (oldPixels + addedHeight)
            .clamp(0.0, newMaxExtent)
            .toDouble();

        _scrollController.jumpTo(target);
      });
    } finally {
      _loadingOlder = false;
    }
  }

  // ===================================================
  // SEND
  // ===================================================

  Future<void> _sendMessage(String message) async {
    final reply = _replyingTo;

    await ref
        .read(roomChatControllerProvider(widget.roomId).notifier)
        .sendMessage(message, replyToMessageId: reply?.id);

    if (!mounted) {
      return;
    }

    if (_replyingTo?.id == reply?.id) {
      setState(() {
        _replyingTo = null;
      });
    }
  }

  // ===================================================
  // BUILD
  // ===================================================

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final chatState = ref.watch(roomChatControllerProvider(widget.roomId));

    final reactionState = ref.watch(
      roomReactionControllerProvider(widget.roomId),
    );

    final reactions = reactionState.value ?? const <RoomMessageReaction>[];

    // =================================================
    // CURRENT USER
    // =================================================

    final currentUser = ref.watch(authControllerProvider).user;

    final currentUserId = currentUser?.id;

    // RoomMember stores only the userId and membership metadata.
    // The actual AppUser profile is kept in the cache from the profile store
    // and the auth controller, not from the room membership list itself.
    // We intentionally do not try to read member.user here.

    // Свой профиль также держим актуальным
    // напрямую из AuthController.
    if (currentUser != null) {
      _profileCache[currentUser.id] = currentUser;
    }

    // =================================================
    // REACTIONS BY MESSAGE
    // =================================================

    final reactionsByMessage = <String, List<RoomMessageReaction>>{};

    for (final reaction in reactions) {
      reactionsByMessage
          .putIfAbsent(reaction.messageId, () => [])
          .add(reaction);
    }

    // =================================================
    // NEW MESSAGES AUTO SCROLL
    // =================================================

    ref.listen(roomChatControllerProvider(widget.roomId), (previous, next) {
      final previousCount = previous?.value?.length ?? 0;

      final nextCount = next.value?.length ?? 0;

      if (nextCount <= previousCount) {
        return;
      }

      final shouldScroll = previousCount == 0 || _isNearBottom;

      if (shouldScroll) {
        _scrollToBottom(animate: previousCount != 0);
      }
    });

    // =================================================
    // CONTENT
    // =================================================

    final content = SizedBox(
      height: widget.height,
      child: Column(
        children: [
          // =============================================
          // HEADER
          // =============================================
          if (!widget.embedded) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_outline, size: 20),

                  const SizedBox(width: 8),

                  Expanded(
                    child: Text(
                      'Chat',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),
          ],

          // =============================================
          // MESSAGES
          // =============================================
          Expanded(
            child: chatState.when(
              // =========================================
              // LOADING
              // =========================================
              loading: () => const Center(child: CircularProgressIndicator()),

              // =========================================
              // ERROR
              // =========================================
              error: (error, stackTrace) => _ChatError(
                error: error,
                onRetry: () {
                  ref.invalidate(roomChatControllerProvider(widget.roomId));
                },
              ),

              // =========================================
              // DATA
              // =========================================
              data: (messages) {
                if (messages.isEmpty) {
                  return const _EmptyChat();
                }

                return ListView.builder(
                  key: PageStorageKey<String>('chat-${widget.roomId}'),
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];

                    // ===================================
                    // CURRENT PROFILE
                    // ===================================
                    //
                    // Сначала используем кешированный
                    // актуальный профиль.
                    //
                    // Если пользователь никогда ещё
                    // не был загружен в RoomState,
                    // используем snapshot из сообщения.
                    // ===================================

                    final messageUser = _profileCache[message.userId];

                    final replyUser = message.reply == null
                        ? null
                        : _profileCache[message.reply!.userId];

                    return RoomMessageBubble(
                      message: message,

                      // ===============================
                      // CURRENT MESSAGE PROFILE
                      // ===============================
                     
                      // ===============================
                      // CURRENT REPLY PROFILE
                      // ===============================
                      replyUserName: replyUser?.name ?? message.reply?.userName,

                      // ===============================
                      // MESSAGE STATE
                      // ===============================
                      isOwn: message.isOwn(currentUserId),

                      currentUserId: currentUserId,

                      reactions: reactionsByMessage[message.id] ?? const [],

                
                      // ===============================
                      // REPLY
                      // ===============================
                      onReply: () {
                        _startReply(message);
                      },

                      // ===============================
                      // REACTION
                      // ===============================
                      onToggleReaction: (reaction) async {
                        try {
                          await ref
                              .read(
                                roomReactionControllerProvider(
                                  widget.roomId,
                                ).notifier,
                              )
                              .toggleReaction(
                                messageId: message.id,
                                reaction: reaction,
                              );
                        } catch (error) {
                          if (!context.mounted) {
                            return;
                          }

                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Failed to update reaction: $error',
                                ),
                              ),
                            );
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),

          const Divider(height: 1),

          // =============================================
          // COMPOSER
          // =============================================
          Padding(
            padding: const EdgeInsets.all(12),
            child: RoomMessageComposer(
              replyingTo: _replyingTo,
              onCancelReply: _cancelReply,
              onSend: _sendMessage,
            ),
          ),
        ],
      ),
    );

    // =================================================
    // EMBEDDED
    // =================================================

    if (widget.embedded) {
      return content;
    }

    // =================================================
    // STANDALONE CARD
    // =================================================

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }
}

// =====================================================================
// EMPTY
// =====================================================================

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),

            const SizedBox(height: 12),

            Text(
              'No messages yet.',
              style: Theme.of(context).textTheme.titleMedium,
            ),

            const SizedBox(height: 4),

            Text(
              'Start the conversation.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// ERROR
// =====================================================================

class _ChatError extends StatelessWidget {
  const _ChatError({required this.error, required this.onRetry});

  final Object error;

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 42,
              color: Theme.of(context).colorScheme.error,
            ),

            const SizedBox(height: 12),

            const Text('Failed to load chat.'),

            const SizedBox(height: 12),

            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
