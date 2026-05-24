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
  final Map<String, List<Message>> _msgs = {};
  final Map<String, Set<String>> _typing = {};
  bool _roomsLoading = false;

  // Notify chat screen when a new message arrives in a specific room
  final Map<String, VoidCallback> _newMessageListeners = {};

  ChatProvider({required this.api, required this.socket}) {
    socket.onNewMessage = _onMessage;
    socket.onReactionUpdated = _onReaction;
    socket.onUserTyping = _onTyping;
  }

  List<Room> get rooms => _rooms;
  bool get roomsLoading => _roomsLoading;

  List<Message> msgs(String roomId) => _msgs[roomId] ?? [];

  Set<String> typing(String roomId) => _typing[roomId] ?? {};

  void setNewMessageListener(String roomId, VoidCallback cb) {
    _newMessageListeners[roomId] = cb;
  }

  void clearNewMessageListener(String roomId) {
    _newMessageListeners.remove(roomId);
  }

  Future<void> loadRooms() async {
    _roomsLoading = true;
    notifyListeners();
    try {
      _rooms = await api.getRooms();
    } catch (_) {
      // Keep existing rooms on error
    } finally {
      _roomsLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMessages(String roomId, {bool refresh = false}) async {
    if (_msgs.containsKey(roomId) && !refresh) return;
    try {
      _msgs[roomId] = await api.getMessages(roomId);
      notifyListeners();
    } catch (_) {
      _msgs[roomId] = [];
      notifyListeners();
    }
  }

  Future<bool> loadOlder(String roomId) async {
    final existing = _msgs[roomId];
    if (existing == null || existing.isEmpty) return false;
    try {
      final older = await api.getMessages(roomId,
          before: existing.first.createdAt.toIso8601String());
      if (older.isEmpty) return false;
      _msgs[roomId] = [...older, ...existing];
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  void sendMessage(String roomId, String content, {String? replyToId}) {
    socket.sendMessage(roomId: roomId, content: content, replyToId: replyToId);
  }

  void toggleReaction(String messageId, String emoji, String myUsername) {
    for (final msgs in _msgs.values) {
      final msg = msgs.where((m) => m.id == messageId).firstOrNull;
      if (msg == null) continue;
      final existing = msg.reactions
          .where((r) => r.emoji == emoji && r.users.contains(myUsername))
          .firstOrNull;
      if (existing != null) {
        socket.removeReaction(messageId, emoji);
      } else {
        socket.addReaction(messageId, emoji);
      }
      break;
    }
  }

  void sendTyping(String roomId, {required bool isTyping}) =>
      socket.sendTyping(roomId, isTyping: isTyping);

  Future<Room> startDm(String targetUserId) async {
    final data = await api.createDm(targetUserId);
    final room = Room.fromJson(data);
    final existingIdx = _rooms.indexWhere((r) => r.id == room.id);
    if (existingIdx >= 0) {
      return _rooms[existingIdx];
    }
    _rooms = [room, ..._rooms];
    notifyListeners();
    return room;
  }

  Future<Room> createGroup(String name, List<String> memberIds) async {
    final data = await api.createGroup(name, memberIds);
    final room = Room.fromJson(data);
    _rooms = [room, ..._rooms];
    notifyListeners();
    return room;
  }

  Future<List<User>> allUsers() => api.getAllUsers();

  void _onMessage(Message msg) {
    final list = List<Message>.from(_msgs[msg.roomId] ?? []);
    list.add(msg);
    _msgs[msg.roomId] = list;

    // Update room preview
    final idx = _rooms.indexWhere((r) => r.id == msg.roomId);
    if (idx >= 0) {
      final updated = _rooms[idx].copyWith(
        lastMessage: msg.content,
        lastMessageAt: msg.createdAt.toIso8601String(),
      );
      _rooms = [updated, ..._rooms.where((r) => r.id != msg.roomId)];
    }

    // Notify active chat screen so it can scroll
    _newMessageListeners[msg.roomId]?.call();

    notifyListeners();
  }

  void _onReaction(String messageId, List<ReactionCount> reactions) {
    bool changed = false;
    for (final roomId in _msgs.keys) {
      final idx = _msgs[roomId]!.indexWhere((m) => m.id == messageId);
      if (idx < 0) continue;
      final list = List<Message>.from(_msgs[roomId]!);
      list[idx] = list[idx].copyWith(reactions: reactions);
      _msgs[roomId] = list;
      changed = true;
      break;
    }
    if (changed) notifyListeners();
  }

  void _onTyping(String userId, String username, String roomId, bool isTyping) {
    _typing[roomId] ??= {};
    if (isTyping) {
      _typing[roomId]!.add(username);
    } else {
      _typing[roomId]!.remove(username);
    }
    notifyListeners();
  }
}
