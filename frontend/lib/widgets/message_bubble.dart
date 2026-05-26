import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/message.dart';
import '../theme/app_theme.dart';

const _quickEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏', '🔥', '👏'];

class MessageBubble extends StatefulWidget {
  final Message message;
  final bool isMine;
  final bool showSenderName;
  final bool showTail;
  final void Function(String emoji) onReact;
  final VoidCallback onReply;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.showSenderName,
    required this.showTail,
    required this.onReact,
    required this.onReply,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  // Slide-in animation for new messages
  late final AnimationController _entranceCtrl;
  late final Animation<Offset> _entrance;

  // Swipe-to-reply
  double _drag = 0;
  bool _replyTriggered = false;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _entrance = Tween<Offset>(
      begin: Offset(widget.isMine ? 0.3 : -0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic));
    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    final dx = d.delta.dx;
    if (dx > 0) {
      final next = min(_drag + dx * 0.55, 72.0);
      setState(() => _drag = next);
      if (_drag > 52 && !_replyTriggered) {
        _replyTriggered = true;
        HapticFeedback.lightImpact();
      }
    } else if (dx < 0 && _drag > 0) {
      setState(() => _drag = max(0, _drag + dx * 0.7));
    }
  }

  void _onDragEnd(DragEndDetails _) {
    if (_drag > 52) widget.onReply();
    setState(() { _drag = 0; _replyTriggered = false; });
  }

  void _longPress() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ActionsSheet(
        onReact: (e) { Navigator.pop(context); widget.onReact(e); },
        onReply: ()  { Navigator.pop(context); widget.onReply();  },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mine = widget.isMine;
    final msg  = widget.message;
    final bg   = mine ? C.sentBubble : C.recvBubble;

    return GestureDetector(
      onLongPress: _longPress,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: SlideTransition(
        position: _entrance,
        child: Transform.translate(
          offset: Offset(_drag, 0),
          child: Padding(
            padding: EdgeInsets.only(
              left:   mine ? 52 : 4,
              right:  mine ? 4  : 52,
              top:    widget.showTail ? 5 : 1,
              bottom: 1,
            ),
            child: Column(
              crossAxisAlignment:
                  mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Reply icon hint (appears while dragging)
                if (_drag > 20)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: 2,
                      left: mine ? 0 : 8,
                      right: mine ? 8 : 0,
                    ),
                    child: Opacity(
                      opacity: (_drag - 20) / 40,
                      child: const Icon(Icons.reply_rounded,
                          size: 18, color: C.timestamp),
                    ),
                  ),

                _BubbleRow(
                  msg: msg,
                  mine: mine,
                  bg: bg,
                  showTail: widget.showTail,
                  showSenderName: widget.showSenderName,
                ),

                if (msg.reactions.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(
                      top:   3,
                      left:  mine ? 0 : (widget.showTail ? 14 : 6),
                      right: mine ? (widget.showTail ? 14 : 6) : 0,
                    ),
                    child: _ReactionsRow(reactions: msg.reactions, onTap: widget.onReact),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Bubble row (bubble + tail) ────────────────────────────────────────────

class _BubbleRow extends StatelessWidget {
  final Message msg;
  final bool mine, showTail, showSenderName;
  final Color bg;

  const _BubbleRow({
    required this.msg,
    required this.mine,
    required this.bg,
    required this.showTail,
    required this.showSenderName,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment:
          mine ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!mine && showTail)
          CustomPaint(size: const Size(8, 13), painter: _TailPainter(mine: false, color: bg))
        else if (!mine)
          const SizedBox(width: 8),

        Flexible(child: _BubbleBody(msg: msg, mine: mine, bg: bg, showTail: showTail, showSenderName: showSenderName)),

        if (mine && showTail)
          CustomPaint(size: const Size(8, 13), painter: _TailPainter(mine: true, color: bg))
        else if (mine)
          const SizedBox(width: 8),
      ],
    );
  }
}

// ─── Bubble body ───────────────────────────────────────────────────────────

class _BubbleBody extends StatelessWidget {
  final Message msg;
  final bool mine, showTail, showSenderName;
  final Color bg;

  const _BubbleBody({
    required this.msg,
    required this.mine,
    required this.bg,
    required this.showTail,
    required this.showSenderName,
  });

  Color _nameColor(String hex) {
    try { return Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16)); }
    catch (_) { return C.teal; }
  }

  @override
  Widget build(BuildContext context) {
    final tailR = showTail ? const Radius.circular(3) : const Radius.circular(16);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.only(
          topLeft:     const Radius.circular(16),
          topRight:    const Radius.circular(16),
          bottomLeft:  mine ? const Radius.circular(16) : tailR,
          bottomRight: mine ? tailR : const Radius.circular(16),
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(9, 6, 9, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showSenderName && !mine)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                msg.senderUsername,
                style: TextStyle(
                  color: _nameColor(msg.senderColor),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          if (msg.replyTo != null) _ReplyWidget(reply: msg.replyTo!),
          _InlineText(content: msg.content, time: _fmt(msg.createdAt), mine: mine, status: msg.status),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) => DateFormat('HH:mm').format(dt.toLocal());
}

// ─── Inline text + timestamp (no overlap trick) ─────────────────────────────

class _InlineText extends StatelessWidget {
  final String content, time;
  final bool mine;
  final MessageStatus status;

  const _InlineText({
    required this.content,
    required this.time,
    required this.mine,
    required this.status,
  });

  Widget _tick() {
    switch (status) {
      case MessageStatus.pending:
        return const Icon(Icons.access_time_rounded, size: 14, color: C.timestamp);
      case MessageStatus.sent:
        return const Icon(Icons.check_rounded, size: 15, color: C.timestamp);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all_rounded, size: 15, color: C.timestamp);
      case MessageStatus.read:
        return const Icon(Icons.done_all_rounded, size: 15, color: Color(0xFF53BDEB));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reserve space equal to timestamp + tick so they never overlap text
    final spacer = '  $time  ';

    return Stack(
      children: [
        RichText(
          text: TextSpan(children: [
            TextSpan(
              text: content,
              style: const TextStyle(fontSize: 15.5, color: Color(0xFF111B21), height: 1.35),
            ),
            TextSpan(
              text: spacer + (mine ? 'X' : ''),
              style: const TextStyle(fontSize: 11.5, color: Colors.transparent),
            ),
          ]),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(time, style: const TextStyle(fontSize: 11.5, color: C.timestamp, height: 1)),
              if (mine) ...[const SizedBox(width: 3), _tick()],
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Reply preview inside bubble ──────────────────────────────────────────

class _ReplyWidget extends StatelessWidget {
  final ReplyPreview reply;
  const _ReplyWidget({required this.reply});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.07),
        borderRadius: BorderRadius.circular(7),
        border: const Border(left: BorderSide(color: C.replyAccent, width: 3.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(reply.senderUsername,
              style: const TextStyle(color: C.replyAccent, fontWeight: FontWeight.w700, fontSize: 12.5)),
          const SizedBox(height: 1),
          Text(reply.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Color(0xFF54656F))),
        ],
      ),
    );
  }
}

// ─── Reactions row ─────────────────────────────────────────────────────────

class _ReactionsRow extends StatelessWidget {
  final List<ReactionCount> reactions;
  final void Function(String) onTap;
  const _ReactionsRow({required this.reactions, required this.onTap});

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 4,
        runSpacing: 4,
        children: reactions.map((r) {
          return GestureDetector(
            onTap: () => onTap(r.emoji),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFD9D9D9)),
                boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 3)],
              ),
              child: Text(r.count > 1 ? '${r.emoji} ${r.count}' : r.emoji,
                  style: const TextStyle(fontSize: 14, height: 1)),
            ),
          );
        }).toList(),
      );
}

// ─── Tail painter ──────────────────────────────────────────────────────────

class _TailPainter extends CustomPainter {
  final bool mine;
  final Color color;
  const _TailPainter({required this.mine, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = color;
    final path = Path();
    if (mine) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(0, size.height);
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    }
    path.close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, Paint()
      ..color = Colors.black.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5);
  }

  @override
  bool shouldRepaint(_TailPainter old) => old.mine != mine || old.color != color;
}

// ─── Long-press actions sheet ───────────────────────────────────────────────

class _ActionsSheet extends StatelessWidget {
  final void Function(String) onReact;
  final VoidCallback onReply;
  const _ActionsSheet({required this.onReact, required this.onReply});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 12, right: 12, top: 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 4))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _quickEmojis.map((e) => _EmojiBtn(emoji: e, onTap: () => onReact(e))).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onReply,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                  child: Row(
                    children: [
                      Icon(Icons.reply_rounded, color: C.teal, size: 22),
                      SizedBox(width: 14),
                      Text('Reply', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmojiBtn extends StatefulWidget {
  final String emoji;
  final VoidCallback onTap;
  const _EmojiBtn({required this.emoji, required this.onTap});

  @override
  State<_EmojiBtn> createState() => _EmojiBtnState();
}

class _EmojiBtnState extends State<_EmojiBtn> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1, end: 1.5)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
        onTapCancel: () => _ctrl.reverse(),
        child: ScaleTransition(
          scale: _scale,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Text(widget.emoji, style: const TextStyle(fontSize: 28)),
          ),
        ),
      );
}
