class Room {
  final String id;
  final String name;
  final bool isGroup;
  final String avatarColor;
  final String? lastMessage;
  final String? lastMessageAt;
  final String? lastMessageSender;
  final int unreadCount;

  const Room({
    required this.id,
    required this.name,
    required this.isGroup,
    required this.avatarColor,
    this.lastMessage,
    this.lastMessageAt,
    this.lastMessageSender,
    this.unreadCount = 0,
  });

  factory Room.fromJson(Map<String, dynamic> j) => Room(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? 'Chat',
        isGroup: (j['is_group'] as int? ?? 0) == 1,
        avatarColor: (j['avatar_color'] as String?) ?? '#075E54',
        lastMessage: j['last_message'] as String?,
        lastMessageAt: j['last_message_at'] as String?,
        lastMessageSender: j['last_message_sender'] as String?,
        unreadCount: (j['unread_count'] as int?) ?? 0,
      );

  Room copyWith({
    String? lastMessage,
    String? lastMessageAt,
    String? lastMessageSender,
    int? unreadCount,
  }) =>
      Room(
        id: id,
        name: name,
        isGroup: isGroup,
        avatarColor: avatarColor,
        lastMessage: lastMessage ?? this.lastMessage,
        lastMessageAt: lastMessageAt ?? this.lastMessageAt,
        lastMessageSender: lastMessageSender ?? this.lastMessageSender,
        unreadCount: unreadCount ?? this.unreadCount,
      );
}
