import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/message.dart';
import '../theme/app_theme.dart';
import 'reaction_picker.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMine;
  final bool showSenderName;
  final void Function(String emoji) onReact;
  final VoidCallback onReply;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.showSenderName,
    required this.onReact,
    required this.onReply,
  });

  Color _hexToColor(String hex) {
    final clean = hex.replaceFirst('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  }

  void _showContextMenu(BuildContext context, Offset position) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;

    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem(
          padding: EdgeInsets.zero,
          child: ReactionPicker(onSelect: (emoji) {
            Navigator.pop(context);
            onReact(emoji);
          }),
        ),
        PopupMenuItem(
          onTap: onReply,
          child: const Row(
            children: [
              Icon(Icons.reply, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Reply'),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMine ? AppColors.sentBubble : AppColors.receivedBubble;
    final alignment = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final timeStr = DateFormat('HH:mm').format(message.createdAt.toLocal());

    return GestureDetector(
      onLongPressStart: (details) => _showContextMenu(context, details.globalPosition),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
        child: Column(
          crossAxisAlignment: alignment,
          children: [
            Row(
              mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isMine) ...[
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.72,
                    ),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMine ? 16 : 4),
                        bottomRight: Radius.circular(isMine ? 4 : 16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showSenderName && !isMine)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                message.senderUsername,
                                style: TextStyle(
                                  color: _hexToColor(message.senderColor),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          if (message.replyTo != null)
                            _ReplyPreviewWidget(reply: message.replyTo!),
                          Text(
                            message.content,
                            style: const TextStyle(fontSize: 15, color: Colors.black87),
                          ),
                          const SizedBox(height: 2),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Text(
                              timeStr,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.timestamp,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (message.reactions.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(
                  top: 2,
                  left: isMine ? 0 : 12,
                  right: isMine ? 12 : 0,
                ),
                child: _ReactionsRow(
                  reactions: message.reactions,
                  onTap: (emoji) => onReact(emoji),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReplyPreviewWidget extends StatelessWidget {
  final ReplyPreview reply;

  const _ReplyPreviewWidget({required this.reply});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: AppColors.replyBg,
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: AppColors.primary, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reply.senderUsername,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
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

class _ReactionsRow extends StatelessWidget {
  final List<ReactionCount> reactions;
  final void Function(String emoji) onTap;

  const _ReactionsRow({required this.reactions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      children: reactions.map((r) {
        return GestureDetector(
          onTap: () => onTap(r.emoji),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 3,
                ),
              ],
            ),
            child: Text(
              '${r.emoji} ${r.count}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        );
      }).toList(),
    );
  }
}
