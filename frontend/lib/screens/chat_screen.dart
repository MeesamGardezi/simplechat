import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
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
  final _scroll = ScrollController();
  ReplyPreview? _replyingTo;
  bool _loadingOlder = false;
  bool _atBottom = true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final chat = context.read<ChatProvider>();
      await chat.loadMessages(widget.room.id);
      chat.socket.joinRoom(widget.room.id);
      _jumpToBottom();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scroll.position;
    _atBottom = pos.pixels >= pos.maxScrollExtent - 80;
    if (pos.pixels <= 120 && !_loadingOlder) _loadOlder();
  }

  Future<void> _loadOlder() async {
    setState(() => _loadingOlder = true);
    await context.read<ChatProvider>().loadOlder(widget.room.id);
    setState(() => _loadingOlder = false);
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  void _animateToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send(String content, String? replyToId) {
    context.read<ChatProvider>().sendMessage(widget.room.id, content, replyToId: replyToId);
    setState(() => _replyingTo = null);
    _animateToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final me = context.read<AuthProvider>().user!;
    final chat = context.watch<ChatProvider>();
    final messages = chat.msgs(widget.room.id);
    final typingNames = chat.typing(widget.room.id);

    // Scroll to bottom on new own message
    if (messages.isNotEmpty && messages.last.senderId == me.id && _atBottom) {
      _animateToBottom();
    }

    return Scaffold(
      backgroundColor: C.chatBg,
      appBar: _ChatAppBar(room: widget.room, typingNames: typingNames),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: messages.length + (_loadingOlder ? 1 : 0),
              itemBuilder: (ctx, i) {
                if (_loadingOlder && i == 0) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: C.teal))),
                  );
                }
                final idx = _loadingOlder ? i - 1 : i;
                final msg = messages[idx];
                final mine = msg.senderId == me.id;
                final prev = idx > 0 ? messages[idx - 1] : null;
                final next = idx < messages.length - 1 ? messages[idx + 1] : null;

                // Date separator
                final showDate = prev == null ||
                    !_sameDay(msg.createdAt, prev.createdAt);

                // Grouping: same sender within 2 minutes of previous
                final isGrouped = !showDate &&
                    prev != null &&
                    prev.senderId == msg.senderId &&
                    msg.createdAt.difference(prev.createdAt).inMinutes < 2;

                final showName = widget.room.isGroup && !mine && !isGrouped;

                return Column(
                  children: [
                    if (showDate) _DateChip(date: msg.createdAt),
                    MessageBubble(
                      key: ValueKey(msg.id),
                      message: msg,
                      isMine: mine,
                      showSenderName: showName,
                      isGrouped: isGrouped,
                      onReact: (emoji) => chat.toggleReaction(msg.id, emoji, me.username),
                      onReply: () => setState(() {
                        _replyingTo = ReplyPreview(
                          id: msg.id,
                          senderUsername: msg.senderUsername,
                          content: msg.content,
                        );
                      }),
                    ),
                  ],
                );
              },
            ),
          ),
          MessageInput(
            onSend: _send,
            onTyping: (t) => chat.sendTyping(widget.room.id, isTyping: t),
            replyingTo: _replyingTo,
            onCancelReply: () => setState(() => _replyingTo = null),
          ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Room room;
  final Set<String> typingNames;

  const _ChatAppBar({required this.room, required this.typingNames});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final subtitle = typingNames.isNotEmpty
        ? 'typing...'
        : room.isGroup
            ? 'Group'
            : 'tap here for info';

    return AppBar(
      leadingWidth: 28,
      titleSpacing: 0,
      title: Row(
        children: [
          UserAvatar(name: room.name, colorHex: room.avatarColor, radius: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  room.name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  typingNames.isNotEmpty
                      ? '${typingNames.first} is typing...'
                      : subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: typingNames.isNotEmpty ? Colors.greenAccent.shade100 : Colors.white60,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final DateTime date;

  const _DateChip({required this.date});

  String _label() {
    final now = DateTime.now();
    final local = date.toLocal();
    if (_sameDay(local, now)) return 'Today';
    if (_sameDay(local, now.subtract(const Duration(days: 1)))) return 'Yesterday';
    return DateFormat('MMMM d, y').format(local);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFD1F0E8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          _label(),
          style: const TextStyle(fontSize: 12, color: Color(0xFF4A6B5B), fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
