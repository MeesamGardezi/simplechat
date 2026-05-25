import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/message.dart';
import '../models/room.dart';
import '../services/auth_provider.dart';
import '../services/chat_provider.dart';
import '../services/socket_service.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar.dart';
import '../widgets/connection_banner.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input.dart';

class ChatScreen extends StatefulWidget {
  final Room room;
  const ChatScreen({super.key, required this.room});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _scroll = ScrollController();
  ReplyPreview? _replyingTo;
  bool _loadingOlder = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);

    final chat = context.read<ChatProvider>();

    // Register per-room listener — called by ChatProvider on new message,
    // NOT from inside build().
    chat.setMsgListener(widget.room.id, _onNewMessage);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await chat.loadMessages(widget.room.id);
      chat.socket.joinRoom(widget.room.id);
      _markRead();
      _jumpBottom();
    });
  }

  @override
  void dispose() {
    context.read<ChatProvider>().clearMsgListener(widget.room.id);
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _markRead();
  }

  void _markRead() {
    final myId = context.read<AuthProvider>().user?.id;
    if (myId != null) {
      context.read<ChatProvider>().markRoomRead(widget.room.id, myId);
    }
  }

  void _onScroll() {
    if (_scroll.position.pixels <= 80 && !_loadingOlder && _hasMore) {
      _loadOlder();
    }
    // Mark as read when user scrolls to bottom
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 60) {
      _markRead();
    }
  }

  Future<void> _loadOlder() async {
    setState(() => _loadingOlder = true);
    final hadMore = await context.read<ChatProvider>().loadOlder(widget.room.id);
    if (mounted) setState(() { _loadingOlder = false; if (!hadMore) _hasMore = false; });
  }

  void _onNewMessage() {
    _markRead();
    final msgs = context.read<ChatProvider>().msgs(widget.room.id);
    if (msgs.isEmpty) return;
    // Auto-scroll only if near bottom
    if (!_scroll.hasClients) return;
    final nearBottom = _scroll.position.maxScrollExtent - _scroll.position.pixels < 200;
    if (nearBottom) _animateBottom();
  }

  void _jumpBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients && _scroll.position.hasContentDimensions) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  void _animateBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients && _scroll.position.hasContentDimensions) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _send(String content, String? replyToId) {
    final me = context.read<AuthProvider>().user!;
    context.read<ChatProvider>().sendMessage(
      widget.room.id,
      content,
      replyToId: replyToId,
      senderId: me.id,
      senderUsername: me.username,
      senderColor: me.avatarColor,
      replyTo: replyToId != null ? _replyingTo : null,
    );
    if (mounted) setState(() => _replyingTo = null);
    _animateBottom();
  }

  @override
  Widget build(BuildContext context) {
    final me     = context.read<AuthProvider>().user!;
    final chat   = context.watch<ChatProvider>();
    final socket = context.read<SocketService>();
    final msgs   = chat.msgs(widget.room.id);
    final typers = chat.typing(widget.room.id)
        .where((u) => u != me.username)
        .toSet();

    return Scaffold(
      backgroundColor: C.chatBg,
      appBar: _ChatAppBar(
        room: widget.room,
        chat: chat,
        typers: typers,
        myUserId: me.id,
      ),
      body: Column(
        children: [
          ConnectionBanner(socket: socket),
          Expanded(
            child: msgs.isEmpty && !_loadingOlder
                ? const _EmptyChat()
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: msgs.length + (_loadingOlder ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (_loadingOlder && i == 0) return _spinner();
                      final idx  = _loadingOlder ? i - 1 : i;
                      final msg  = msgs[idx];
                      final prev = idx > 0 ? msgs[idx - 1] : null;
                      final mine = msg.senderId == me.id;

                      final newDay = prev == null ||
                          !_sameDay(msg.createdAt, prev.createdAt);
                      final grouped = !newDay &&
                          prev != null &&
                          prev.senderId == msg.senderId &&
                          msg.createdAt.difference(prev.createdAt).inMinutes < 3;

                      return Column(children: [
                        if (newDay) _DateChip(date: msg.createdAt),
                        MessageBubble(
                          key: ValueKey(msg.id),
                          message: msg,
                          isMine: mine,
                          showSenderName: widget.room.isGroup && !mine && !grouped,
                          showTail: !grouped,
                          onReact: (e) => chat.toggleReaction(msg.id, e, me.username),
                          onReply: () => setState(() => _replyingTo = ReplyPreview(
                                id: msg.id,
                                senderUsername: msg.senderUsername,
                                content: msg.content,
                              )),
                        ),
                      ]);
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

  bool _sameDay(DateTime a, DateTime b) {
    final la = a.toLocal(); final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }

  Widget _spinner() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 22, height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: C.teal),
          ),
        ),
      );
}

// ─── AppBar ────────────────────────────────────────────────────────────────

class _ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Room room;
  final ChatProvider chat;
  final Set<String> typers;
  final String myUserId;

  const _ChatAppBar({
    required this.room,
    required this.chat,
    required this.typers,
    required this.myUserId,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  String _subtitle() {
    if (typers.isNotEmpty) {
      return typers.length == 1
          ? '${typers.first} is typing…'
          : 'Several people are typing…';
    }
    if (!room.isGroup) {
      // For DMs, find the other user's online/last-seen status
      // We look them up via room members in a real app; here we use presence map
      return '';
    }
    return '${room.name} · group';
  }

  Color _subtitleColor() => typers.isNotEmpty
      ? const Color(0xFF90EE90)  // light green for typing
      : Colors.white60;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leadingWidth: 30,
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
                  style: const TextStyle(
                    color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_subtitle().isNotEmpty)
                  Text(
                    _subtitle(),
                    style: TextStyle(color: _subtitleColor(), fontSize: 12.5),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty chat hint ───────────────────────────────────────────────────────

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();
  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFFD1F0E8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Messages are end-to-end encrypted. Say hello! 👋',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF4A6B5B)),
          ),
        ),
      );
}

// ─── Date chip ─────────────────────────────────────────────────────────────

class _DateChip extends StatelessWidget {
  final DateTime date;
  const _DateChip({required this.date});

  String _label() {
    final l = date.toLocal(), now = DateTime.now();
    if (_s(l, now)) return 'Today';
    if (_s(l, now.subtract(const Duration(days: 1)))) return 'Yesterday';
    return DateFormat('MMMM d, y').format(l);
  }

  bool _s(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) => Padding(
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
