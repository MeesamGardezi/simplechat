enum MessageStatus { pending, sent, delivered, read }

class ReactionCount {
  final String emoji;
  final int count;
  final List<String> users;

  const ReactionCount({required this.emoji, required this.count, required this.users});

  factory ReactionCount.fromJson(Map<String, dynamic> j) => ReactionCount(
        emoji: j['emoji'] as String,
        count: j['count'] as int,
        users: List<String>.from(j['users'] as List),
      );
}

class ReplyPreview {
  final String id;
  final String senderUsername;
  final String content;

  const ReplyPreview({required this.id, required this.senderUsername, required this.content});

  factory ReplyPreview.fromJson(Map<String, dynamic> j) => ReplyPreview(
        id: j['id'] as String,
        senderUsername: j['sender_username'] as String,
        content: j['content'] as String,
      );
}

class Message {
  final String id;
  final String roomId;
  final String senderId;
  final String senderUsername;
  final String senderColor;
  final String content;
  final String? replyToId;
  final ReplyPreview? replyTo;
  final List<ReactionCount> reactions;
  final DateTime createdAt;
  final MessageStatus status;

  /// Client-generated ID for optimistic messages. Null once server confirms.
  final String? clientId;

  const Message({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderUsername,
    required this.senderColor,
    required this.content,
    this.replyToId,
    this.replyTo,
    required this.reactions,
    required this.createdAt,
    required this.status,
    this.clientId,
  });

  factory Message.fromJson(Map<String, dynamic> j) => Message(
        id: j['id'] as String,
        roomId: j['room_id'] as String,
        senderId: j['sender_id'] as String,
        senderUsername: j['sender_username'] as String,
        senderColor: j['sender_color'] as String? ?? '#075E54',
        content: j['content'] as String,
        replyToId: j['reply_to_id'] as String?,
        replyTo: j['reply_to'] != null
            ? ReplyPreview.fromJson(j['reply_to'] as Map<String, dynamic>)
            : null,
        reactions: (j['reactions'] as List<dynamic>? ?? [])
            .map((r) => ReactionCount.fromJson(r as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(j['created_at'] as String),
        status: _parseStatus(j['status'] as String?),
        clientId: j['client_id'] as String?,
      );

  static MessageStatus _parseStatus(String? s) {
    switch (s) {
      case 'delivered': return MessageStatus.delivered;
      case 'read':      return MessageStatus.read;
      case 'pending':   return MessageStatus.pending;
      default:          return MessageStatus.sent;
    }
  }

  Message copyWith({
    List<ReactionCount>? reactions,
    MessageStatus? status,
    String? clientId,
  }) =>
      Message(
        id: id,
        roomId: roomId,
        senderId: senderId,
        senderUsername: senderUsername,
        senderColor: senderColor,
        content: content,
        replyToId: replyToId,
        replyTo: replyTo,
        reactions: reactions ?? this.reactions,
        createdAt: createdAt,
        status: status ?? this.status,
        clientId: clientId ?? this.clientId,
      );
}
