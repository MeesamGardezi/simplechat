class User {
  final String id;
  final String username;
  final String email;
  final String avatarColor;

  const User({
    required this.id,
    required this.username,
    required this.email,
    required this.avatarColor,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        username: json['username'] as String,
        email: json['email'] as String,
        avatarColor: json['avatar_color'] as String? ?? '#075E54',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'avatar_color': avatarColor,
      };
}
