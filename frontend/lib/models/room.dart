class Room {
  final String id;
  final String name;
  final bool isGroup;
  final String avatarColor;
  final String? lastMessage;
  final String? lastMessageAt;

  const Room({
    required this.id,
    required this.name,
    required this.isGroup,
    required this.avatarColor,
    this.lastMessage,
    this.lastMessageAt,
  });

  factory Room.fromJson(Map<String, dynamic> json) => Room(
        id: json['id'] as String,
        name: json['name'] as String,
        isGroup: (json['is_group'] as int? ?? 0) == 1,
        avatarColor: json['avatar_color'] as String? ?? '#075E54',
        lastMessage: json['last_message'] as String?,
        lastMessageAt: json['last_message_at'] as String?,
      );

  Room copyWith({String? lastMessage, String? lastMessageAt}) => Room(
        id: id,
        name: name,
        isGroup: isGroup,
        avatarColor: avatarColor,
        lastMessage: lastMessage ?? this.lastMessage,
        lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      );
}
