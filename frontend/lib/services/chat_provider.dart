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

  ChatProvider({required this.api, required this.socket}) {
    socket.onNewMessage = _onMessage;
    socket.onReactionUpdated = _onReaction;
    socket.onUserTyping = _onTyping;
  }

  List<Room> get rooms => _rooms;
  bool get roomsLoading => _roomsLoading;
  List<Message> msgs(String roomId) => _msgs[roomId] ?? [];
  Set<String> typing(String roomId) => _typing[roomId] ?? {};

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
    if (_msgs.containsKey(roomId) && !refresh) return;
    _msgs[roomId] = await api.getMessages(roomId);
    notifyListeners();
  }

  Future<void> loadOlder(String roomId) async {
    final existing = _msgs[roomId] ?? [];
    if (existing.isEmpty) return;
    final older = await api.getMessages(roomId, before: existing.first.createdAt.toIso8601String());
    if (older.isNotEmpty) {
      _msgs[roomId] = [...older, ...existing];
      notifyListeners();
    }
  }

  void sendMessage(String roomId, String content, {String? replyToId}) {
    socket.sendMessage(roomId: roomId, content: content, replyToId: replyToId);
  }

  void toggleReaction(String messageId, String emoji, String myUsername) {
    for (final msgs in _msgs.values) {
      final idx = msgs.indexWhere((m) => m.id == messageId);
      if (idx < 0) continue;
      final msg = msgs[idx];
      final existing = msg.reactions.where((r) => r.emoji == emoji).firstOrNull;
      if (existing != null && existing.users.contains(myUsername)) {
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
    if (!_rooms.any((r) => r.id == room.id)) {
      _rooms = [room, ..._rooms];
      notifyListeners();
    } else {
      return _rooms.firstWhere((r) => r.id == room.id);
    }
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
    _msgs[msg.roomId] = [...(_msgs[msg.roomId] ?? []), msg];
    final idx = _rooms.indexWhere((r) => r.id == msg.roomId);
    if (idx >= 0) {
      final updated = _rooms[idx].copyWith(
        lastMessage: msg.content,
        lastMessageAt: msg.createdAt.toIso8601String(),
      );
      _rooms = [updated, ..._rooms.where((r) => r.id != msg.roomId)];
    }
    notifyListeners();
  }

  void _onReaction(String messageId, List<ReactionCount> reactions) {
    for (final roomId in _msgs.keys) {
      final idx = _msgs[roomId]!.indexWhere((m) => m.id == messageId);
      if (idx < 0) continue;
      final list = List<Message>.from(_msgs[roomId]!);
      list[idx] = list[idx].copyWith(reactions: reactions);
      _msgs[roomId] = list;
      notifyListeners();
      break;
    }
  }

  void _onTyping(String userId, String username, String roomId, bool isTyping) {
    _typing[roomId] ??= {};
    isTyping ? _typing[roomId]!.add(username) : _typing[roomId]!.remove(username);
    notifyListeners();
  }
}
