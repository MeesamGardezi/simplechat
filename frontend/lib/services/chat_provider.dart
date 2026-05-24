import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../models/room.dart';
import '../models/user.dart';
import 'api_service.dart';
import 'socket_service.dart';

class ChatProvider extends ChangeNotifier {
  final ApiService api;
  final SocketService socket;

  List<Room> _rooms = [];
  final Map<String, List<Message>> _messages = {};
  final Map<String, Set<String>> _typingUsers = {};
  bool _roomsLoading = false;

  ChatProvider({required this.api, required this.socket}) {
    socket.onNewMessage = _handleNewMessage;
    socket.onReactionUpdated = _handleReactionUpdated;
    socket.onUserTyping = _handleUserTyping;
  }

  List<Room> get rooms => _rooms;
  bool get roomsLoading => _roomsLoading;

  List<Message> messagesFor(String roomId) => _messages[roomId] ?? [];

  Set<String> typingUsersFor(String roomId) => _typingUsers[roomId] ?? {};

  Future<void> loadRooms() async {
    _roomsLoading = true;
    notifyListeners();

    try {
      _rooms = await api.getRooms();
    } finally {
      _roomsLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMessages(String roomId, {bool refresh = false}) async {
    if (_messages.containsKey(roomId) && !refresh) return;
    final msgs = await api.getMessages(roomId);
    _messages[roomId] = msgs;
    notifyListeners();
  }

  Future<void> loadMoreMessages(String roomId) async {
    final existing = _messages[roomId] ?? [];
    if (existing.isEmpty) return;

    final oldest = existing.first.createdAt.toIso8601String();
    final older = await api.getMessages(roomId, before: oldest);
    if (older.isNotEmpty) {
      _messages[roomId] = [...older, ...existing];
      notifyListeners();
    }
  }

  void sendMessage({
    required String roomId,
    required String content,
    String? replyToId,
  }) {
    socket.sendMessage(roomId: roomId, content: content, replyToId: replyToId);
  }

  void toggleReaction(String messageId, String emoji, String currentUserId) {
    final msgs = _messages.values.expand((m) => m).where((m) => m.id == messageId);
    if (msgs.isEmpty) return;

    final msg = msgs.first;
    final existing = msg.reactions.firstWhere(
      (r) => r.emoji == emoji && r.users.contains(_currentUsername(currentUserId)),
      orElse: () => ReactionCount(emoji: emoji, count: 0, users: []),
    );

    if (existing.count > 0) {
      socket.removeReaction(messageId, emoji);
    } else {
      socket.addReaction(messageId, emoji);
    }
  }

  void sendTyping(String roomId, {required bool isTyping}) {
    socket.sendTyping(roomId, isTyping: isTyping);
  }

  Future<Room> startDm(String targetUserId) async {
    final room = await api.createDm(targetUserId);
    if (!_rooms.any((r) => r.id == room.id)) {
      _rooms = [room, ..._rooms];
      notifyListeners();
    }
    return room;
  }

  Future<Room> createGroup({required String name, required List<String> memberIds}) async {
    final room = await api.createGroup(name: name, memberIds: memberIds);
    _rooms = [room, ..._rooms];
    notifyListeners();
    return room;
  }

  Future<List<User>> getAllUsers() => api.getAllUsers();

  void _handleNewMessage(Message message) {
    final roomId = message.roomId;
    _messages[roomId] = [...(_messages[roomId] ?? []), message];

    final roomIndex = _rooms.indexWhere((r) => r.id == roomId);
    if (roomIndex >= 0) {
      final updated = _rooms[roomIndex].copyWith(
        lastMessage: message.content,
        lastMessageAt: message.createdAt.toIso8601String(),
      );
      _rooms = [
        updated,
        ..._rooms.where((r) => r.id != roomId),
      ];
    }

    notifyListeners();
  }

  void _handleReactionUpdated(String messageId, List<ReactionCount> reactions) {
    for (final roomId in _messages.keys) {
      final msgs = _messages[roomId]!;
      final idx = msgs.indexWhere((m) => m.id == messageId);
      if (idx >= 0) {
        final updated = List<Message>.from(msgs);
        updated[idx] = msgs[idx].copyWith(reactions: reactions);
        _messages[roomId] = updated;
        notifyListeners();
        break;
      }
    }
  }

  void _handleUserTyping(String userId, String username, String roomId, bool isTyping) {
    _typingUsers[roomId] ??= {};
    if (isTyping) {
      _typingUsers[roomId]!.add(username);
    } else {
      _typingUsers[roomId]!.remove(username);
    }
    notifyListeners();
  }

  String _currentUsername(String userId) {
    // used only for optimistic reaction check — not critical
    return userId;
  }
}
