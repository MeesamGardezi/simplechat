import 'package:flutter/material.dart';
import '../models/message.dart';
import '../theme/app_theme.dart';

class MessageInput extends StatefulWidget {
  final void Function(String content, String? replyToId) onSend;
  final void Function(bool) onTyping;
  final ReplyPreview? replyingTo;
  final VoidCallback? onCancelReply;

  const MessageInput({
    super.key,
    required this.onSend,
    required this.onTyping,
    this.replyingTo,
    this.onCancelReply,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final _ctrl = TextEditingController();
  bool _hasText = false;
  bool _wasTyping = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onChanged);
  }

  void _onChanged() {
    final has = _ctrl.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
    if (has && !_wasTyping) {
      _wasTyping = true;
      widget.onTyping(true);
    } else if (!has && _wasTyping) {
      _wasTyping = false;
      widget.onTyping(false);
    }
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final replyId = widget.replyingTo?.id;
    _ctrl.clear();
    _wasTyping = false;
    widget.onTyping(false);
    widget.onSend(text, replyId);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: C.inputBg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.replyingTo != null) _ReplyBar(reply: widget.replyingTo!, onCancel: widget.onCancelReply!),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 130),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextField(
                              controller: _ctrl,
                              minLines: 1,
                              maxLines: 6,
                              textCapitalization: TextCapitalization.sentences,
                              style: const TextStyle(fontSize: 15.5, color: Colors.black87),
                              decoration: const InputDecoration(
                                hintText: 'Message',
                                hintStyle: TextStyle(color: Colors.black38, fontSize: 15.5),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 11),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _hasText ? _send : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: _hasText ? C.green : Colors.grey.shade400,
                        shape: BoxShape.circle,
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Icon(
                          _hasText ? Icons.send_rounded : Icons.mic_rounded,
                          key: ValueKey(_hasText),
                          color: Colors.white,
                          size: 21,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplyBar extends StatelessWidget {
  final ReplyPreview reply;
  final VoidCallback onCancel;

  const _ReplyBar({required this.reply, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: C.divider)),
      ),
      child: Row(
        children: [
          Container(width: 3, height: 36, decoration: BoxDecoration(color: C.replyStripe, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reply.senderUsername,
                  style: const TextStyle(color: C.replyStripe, fontWeight: FontWeight.w700, fontSize: 13),
                ),
                Text(
                  reply.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Colors.black45),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCancel,
            icon: const Icon(Icons.close, size: 20, color: Colors.black38),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }
}
