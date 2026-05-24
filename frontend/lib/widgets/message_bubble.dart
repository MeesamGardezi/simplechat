import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/message.dart';
import '../theme/app_theme.dart';

const _kQuickEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏', '🔥', '👏'];

class MessageBubble extends StatefulWidget {
  final Message message;
  final bool isMine;
  final bool showSenderName;
  final bool isGrouped; // true when same sender as previous message
  final void Function(String emoji) onReact;
  final VoidCallback onReply;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.showSenderName,
    required this.isGrouped,
    required this.onReact,
    required this.onReply,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  double _drag = 0;
  bool _triggered = false;

  void _onDragUpdate(DragUpdateDetails d) {
    final delta = d.delta.dx;
    if (delta > 0) {
      setState(() => _drag = min(_drag + delta * 0.6, 64));
      if (_drag >= 48 && !_triggered) {
        _triggered = true;
        HapticFeedback.lightImpact();
      }
    }
  }

  void _onDragEnd(DragEndDetails _) {
    if (_drag >= 48) widget.onReply();
    setState(() {
      _drag = 0;
      _triggered = false;
    });
  }

  void _longPress() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ActionSheet(
        message: widget.message,
        onReact: (e) {
          Navigator.pop(context);
          widget.onReact(e);
        },
        onReply: () {
          Navigator.pop(context);
          widget.onReply();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.message;
    final mine = widget.isMine;
    final showTail = !widget.isGrouped;

    return GestureDetector(
      onLongPress: _longPress,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: Transform.translate(
        offset: Offset(_drag, 0),
        child: Padding(
          padding: EdgeInsets.only(
            left: mine ? 64 : 8,
            right: mine ? 8 : 64,
            top: widget.isGrouped ? 2 : 6,
            bottom: 2,
          ),
          child: Column(
            crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              _Bubble(msg: msg, mine: mine, showTail: showTail, showName: widget.showSenderName),
              if (msg.reactions.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(
                    top: 3,
                    left: mine ? 0 : 12,
                    right: mine ? 12 : 0,
                  ),
                  child: _ReactionsBar(reactions: msg.reactions, onTap: widget.onReact),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Bubble ────────────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  final Message msg;
  final bool mine;
  final bool showTail;
  final bool showName;

  const _Bubble({
    required this.msg,
    required this.mine,
    required this.showTail,
    required this.showName,
  });

  Color _nameColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
    } catch (_) {
      return C.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = mine ? C.sentBubble : C.recvBubble;
    final time = DateFormat('HH:mm').format(msg.createdAt.toLocal());

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!mine && showTail) _Tail(color: bg, mine: false),
        Flexible(
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(mine ? 16 : (showTail ? 2 : 16)),
                    bottomRight: Radius.circular(mine ? (showTail ? 2 : 16) : 16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.07),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showName && !mine)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          msg.senderUsername,
                          style: TextStyle(
                            color: _nameColor(msg.senderColor),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    if (msg.replyTo != null) _ReplyPreviewWidget(reply: msg.replyTo!),
                    _MessageText(content: msg.content, time: time, mine: mine),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (mine && showTail) _Tail(color: bg, mine: true),
      ],
    );
  }
}

// ─── Tail ──────────────────────────────────────────────────────────────────

class _Tail extends StatelessWidget {
  final Color color;
  final bool mine;

  const _Tail({required this.color, required this.mine});

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: const Size(8, 14),
        painter: _TailPainter(color: color, mine: mine),
      );
}

class _TailPainter extends CustomPainter {
  final Color color;
  final bool mine;

  const _TailPainter({required this.color, required this.mine});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    final path = Path();
    if (mine) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    }
    path.close();
    canvas.drawPath(path, p);
    canvas.drawPath(path, Paint()..color = Colors.black.withOpacity(0.04));
  }

  @override
  bool shouldRepaint(_TailPainter old) => old.color != color || old.mine != mine;
}

// ─── Message text with inline timestamp ───────────────────────────────────

class _MessageText extends StatelessWidget {
  final String content;
  final String time;
  final bool mine;

  const _MessageText({required this.content, required this.time, required this.mine});

  @override
  Widget build(BuildContext context) {
    // Pad content with invisible timestamp width so timestamp never overlaps text
    return Stack(
      children: [
        Padding(
          // Reserve space for the timestamp at the end
          padding: const EdgeInsets.only(bottom: 0),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: content,
                  style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.35),
                ),
                // invisible spacer matching timestamp width
                const TextSpan(
                  text: '  00:00',
                  style: TextStyle(fontSize: 11, color: Colors.transparent),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                time,
                style: TextStyle(
                  fontSize: 11,
                  color: mine ? const Color(0xFF8696A0) : Colors.black38,
                ),
              ),
              if (mine) ...[
                const SizedBox(width: 2),
                const Icon(Icons.done_all, size: 14, color: Color(0xFF53BDEB)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Reply preview inside bubble ──────────────────────────────────────────

class _ReplyPreviewWidget extends StatelessWidget {
  final ReplyPreview reply;

  const _ReplyPreviewWidget({required this.reply});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: const Border(left: BorderSide(color: C.replyStripe, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reply.senderUsername,
            style: const TextStyle(
              color: C.replyStripe,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            reply.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

// ─── Reactions bar ────────────────────────────────────────────────────────

class _ReactionsBar extends StatelessWidget {
  final List<ReactionCount> reactions;
  final void Function(String) onTap;

  const _ReactionsBar({required this.reactions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: reactions.map((r) {
        return GestureDetector(
          onTap: () => onTap(r.emoji),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)],
            ),
            child: Text('${r.emoji} ${r.count}', style: const TextStyle(fontSize: 13)),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Action sheet (long press) ────────────────────────────────────────────

class _ActionSheet extends StatelessWidget {
  final Message message;
  final void Function(String) onReact;
  final VoidCallback onReply;

  const _ActionSheet({required this.message, required this.onReact, required this.onReply});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Emoji row
        Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 4))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _kQuickEmojis.map((e) => _EmojiBtn(emoji: e, onTap: () => onReact(e))).toList(),
          ),
        ),
        // Actions
        Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.reply_rounded, color: C.teal),
                title: const Text('Reply', style: TextStyle(fontWeight: FontWeight.w500)),
                onTap: onReply,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
              ),
            ],
          ),
        ),
      ],
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
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(milliseconds: 120), vsync: this);
    _scale = Tween<double>(begin: 1, end: 1.45).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(widget.emoji, style: const TextStyle(fontSize: 28)),
        ),
      ),
    );
  }
}
