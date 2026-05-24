class ReactionCount {
  final String emoji;
  final int count;
  final List<String> users;

  const ReactionCount({
    required this.emoji,
    required this.count,
    required this.users,
  });

  factory ReactionCount.fromJson(Map<String, dynamic> json) => ReactionCount(
        emoji: json['emoji'] as String,
        count: json['count'] as int,
        users: List<String>.from(json['users'] as List),
      );
}

class ReplyPreview {
  final String id;
  final String senderUsername;
  final String content;

  const ReplyPreview({
    required this.id,
    required this.senderUsername,
    required this.content,
  });

  factory ReplyPreview.fromJson(Map<String, dynamic> json) => ReplyPreview(
        id: json['id'] as String,
        senderUsername: json['sender_username'] as String,
        content: json['content'] as String,
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
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as String,
        roomId: json['room_id'] as String,
        senderId: json['sender_id'] as String,
        senderUsername: json['sender_username'] as String,
        senderColor: json['sender_color'] as String? ?? '#075E54',
        content: json['content'] as String,
        replyToId: json['reply_to_id'] as String?,
        replyTo: json['reply_to'] != null
            ? ReplyPreview.fromJson(json['reply_to'] as Map<String, dynamic>)
            : null,
        reactions: (json['reactions'] as List<dynamic>? ?? [])
            .map((r) => ReactionCount.fromJson(r as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Message copyWith({List<ReactionCount>? reactions}) => Message(
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
      );
}
