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
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);

    final chat = context.read<ChatProvider>();

    // Register listener: called by ChatProvider when new message arrives in this room.
    // This is the ONLY place that calls scroll — never from build().
    chat.setNewMessageListener(widget.room.id, _onNewMessage);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await chat.loadMessages(widget.room.id);
      chat.socket.joinRoom(widget.room.id);
      _jumpBottom();
    });
  }

  @override
  void dispose() {
    context.read<ChatProvider>().clearNewMessageListener(widget.room.id);
    _scroll.dispose();
    super.dispose();
  }

  void _onNewMessage() {
    // Only called from ChatProvider, never from build
    final myId = context.read<AuthProvider>().user?.id;
    final msgs = context.read<ChatProvider>().msgs(widget.room.id);
    if (msgs.isEmpty) return;

    final last = msgs.last;
    final nearBottom = _scroll.hasClients &&
        _scroll.position.maxScrollExtent - _scroll.offset < 200;

    // Always scroll when it's my own message; otherwise only if near bottom
    if (last.senderId == myId || nearBottom) {
      _animateBottom();
    }
  }

  void _onScroll() {
    if (_scroll.position.pixels <= 60 && !_loadingOlder && _hasMore) {
      _loadOlder();
    }
  }

  Future<void> _loadOlder() async {
    setState(() => _loadingOlder = true);
    final hadMore = await context.read<ChatProvider>().loadOlder(widget.room.id);
    if (mounted) setState(() {
      _loadingOlder = false;
      if (!hadMore) _hasMore = false;
    });
  }

  void _jumpBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  void _animateBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send(String content, String? replyToId) {
    context.read<ChatProvider>().sendMessage(
          widget.room.id,
          content,
          replyToId: replyToId,
        );
    setState(() => _replyingTo = null);
    _animateBottom();
  }

  @override
  Widget build(BuildContext context) {
    final me = context.read<AuthProvider>().user!;
    final chat = context.watch<ChatProvider>();
    final messages = chat.msgs(widget.room.id);
    final typingNames = chat.typing(widget.room.id).where((u) => u != me.username).toSet();

    return Scaffold(
      backgroundColor: C.chatBg,
      appBar: _buildAppBar(typingNames),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty && !_loadingOlder
                ? const _EmptyChat()
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: messages.length + (_loadingOlder ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (_loadingOlder && i == 0) return _loadingIndicator();
                      final idx = _loadingOlder ? i - 1 : i;
                      return _buildItem(messages, idx, me.id);
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

  PreferredSizeWidget _buildAppBar(Set<String> typingNames) {
    return AppBar(
      leadingWidth: 30,
      titleSpacing: 0,
      title: GestureDetector(
        onTap: () {}, // room info (future)
        child: Row(
          children: [
            UserAvatar(
              name: widget.room.name,
              colorHex: widget.room.avatarColor,
              radius: 19,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.room.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (typingNames.isNotEmpty)
                    Text(
                      typingNames.length == 1
                          ? '${typingNames.first} is typing…'
                          : 'Several people are typing…',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(List<Message> messages, int idx, String myId) {
    final msg = messages[idx];
    final prev = idx > 0 ? messages[idx - 1] : null;
    final mine = msg.senderId == myId;

    final showDate = prev == null || !_sameDay(msg.createdAt, prev.createdAt);

    // Group messages from same sender within 3 minutes
    final grouped = !showDate &&
        prev != null &&
        prev.senderId == msg.senderId &&
        msg.createdAt.difference(prev.createdAt).inMinutes < 3;

    final showSenderName = widget.room.isGroup && !mine && !grouped;

    return Column(
      children: [
        if (showDate) _DateChip(date: msg.createdAt),
        MessageBubble(
          key: ValueKey(msg.id),
          message: msg,
          isMine: mine,
          showSenderName: showSenderName,
          showTail: !grouped,
          onReact: (emoji) =>
              context.read<ChatProvider>().toggleReaction(msg.id, emoji, me_username(context)),
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
  }

  String me_username(BuildContext context) =>
      context.read<AuthProvider>().user?.username ?? '';

  bool _sameDay(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }

  Widget _loadingIndicator() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: C.teal,
            ),
          ),
        ),
      );
}

// ─── Empty state ───────────────────────────────────────────────────────────

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFD1F0E8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Messages are end-to-end encrypted. Say hello! 👋',
          style: TextStyle(fontSize: 13, color: Color(0xFF4A6B5B)),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ─── Date separator chip ───────────────────────────────────────────────────

class _DateChip extends StatelessWidget {
  final DateTime date;

  const _DateChip({required this.date});

  String _label() {
    final local = date.toLocal();
    final now = DateTime.now();
    if (_same(local, now)) return 'Today';
    if (_same(local, now.subtract(const Duration(days: 1)))) return 'Yesterday';
    return DateFormat('MMMM d, y').format(local);
  }

  bool _same(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFD1F0E8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _label(),
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF3D6158),
            ),
          ),
        ),
      ),
    );
  }
}
