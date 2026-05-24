import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/message.dart';
import '../models/room.dart';
import '../services/auth_provider.dart';
import '../services/chat_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input.dart';

class ChatScreen extends StatefulWidget {
  final Room room;

  const ChatScreen({super.key, required this.room});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _scrollController = ScrollController();
  ReplyPreview? _replyingTo;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadMessages(widget.room.id);
      context.read<ChatProvider>().socket.joinRoom(widget.room.id);
    });

    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels <= 100 && !_loadingMore) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    await context.read<ChatProvider>().loadMoreMessages(widget.room.id);
    setState(() => _loadingMore = false);
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (animated) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      }
    });
  }

  void _sendMessage(String content, String? replyToId) {
    context.read<ChatProvider>().sendMessage(
          roomId: widget.room.id,
          content: content,
          replyToId: replyToId,
        );
    setState(() => _replyingTo = null);
    _scrollToBottom();
  }

  void _onReply(Message message) {
    setState(() {
      _replyingTo = ReplyPreview(
        id: message.id,
        senderUsername: message.senderUsername,
        content: message.content,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final myId = context.read<AuthProvider>().user!.id;
    final chat = context.watch<ChatProvider>();
    final messages = chat.messagesFor(widget.room.id);
    final typingUsers = chat.typingUsersFor(widget.room.id);

    // Auto-scroll when new message arrives
    if (messages.isNotEmpty) {
      final lastMsg = messages.last;
      if (lastMsg.senderId == myId) {
        _scrollToBottom();
      }
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            UserAvatar(name: widget.room.name, colorHex: widget.room.avatarColor, radius: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.room.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  if (typingUsers.isNotEmpty)
                    Text(
                      '${typingUsers.first} is typing...',
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: AppColors.chatBackground,
              child: messages.isEmpty
                  ? const Center(
                      child: Text(
                        'No messages yet.\nSay hello!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 15),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: messages.length + (_loadingMore ? 1 : 0),
                      itemBuilder: (ctx, i) {
                        if (i == 0 && _loadingMore) {
                          return const Padding(
                            padding: EdgeInsets.all(8),
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          );
                        }

                        final msgIndex = _loadingMore ? i - 1 : i;
                        final message = messages[msgIndex];
                        final isMine = message.senderId == myId;

                        final showSenderName = widget.room.isGroup &&
                            !isMine &&
                            (msgIndex == 0 || messages[msgIndex - 1].senderId != message.senderId);

                        return MessageBubble(
                          key: ValueKey(message.id),
                          message: message,
                          isMine: isMine,
                          showSenderName: showSenderName,
                          onReact: (emoji) {
                            chat.toggleReaction(message.id, emoji, myId);
                          },
                          onReply: () => _onReply(message),
                        );
                      },
                    ),
            ),
          ),
          MessageInput(
            onSend: _sendMessage,
            onTyping: (isTyping) => chat.sendTyping(widget.room.id, isTyping: isTyping),
            replyingTo: _replyingTo,
            onCancelReply: () => setState(() => _replyingTo = null),
          ),
        ],
      ),
    );
  }
}
