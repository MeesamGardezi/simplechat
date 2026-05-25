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

  /// userId → isOnline
  final Map<String, bool> _online = {};

  /// userId → last seen DateTime
  final Map<String, DateTime?> _lastSeen = {};

  bool _roomsLoading = false;

  /// Room-level callbacks so chat screen can react to new messages without
  /// calling scroll from inside build().
  final Map<String, VoidCallback> _msgListeners = {};

  ChatProvider({required this.api, required this.socket}) {
    socket.onNewMessage      = _onMessage;
    socket.onReactionUpdated = _onReaction;
    socket.onUserTyping      = _onTyping;
    socket.onRoomReadBy      = _onRoomReadBy;
    socket.onPresenceUpdate  = _onPresence;
    socket.onInitialPresence = _onInitialPresence;
  }

  // ── Public getters ─────────────────────────────────────────────────────────
  List<Room>    get rooms       => _rooms;
  bool          get roomsLoading => _roomsLoading;
  List<Message> msgs(String roomId)    => _msgs[roomId] ?? [];
  Set<String>   typing(String roomId)  => _typing[roomId] ?? {};
  bool          isOnline(String userId) => _online[userId] ?? false;
  DateTime?     lastSeen(String userId) => _lastSeen[userId];
  int           totalUnread()  => _rooms.fold(0, (s, r) => s + r.unreadCount);

  void setMsgListener(String roomId, VoidCallback cb)  => _msgListeners[roomId] = cb;
  void clearMsgListener(String roomId)                 => _msgListeners.remove(roomId);

  // ── Rooms ─────────────────────────────────────────────────────────────────
  Future<void> loadRooms() async {
    _roomsLoading = true;
    notifyListeners();
    try {
      _rooms = await api.getRooms();
    } catch (_) {}
    _roomsLoading = false;
    notifyListeners();
  }

  // ── Messages ──────────────────────────────────────────────────────────────
  Future<void> loadMessages(String roomId, {bool refresh = false}) async {
    if (_msgs.containsKey(roomId) && !refresh) return;
    try {
      _msgs[roomId] = await api.getMessages(roomId);
    } catch (_) {
      _msgs[roomId] = [];
    }
    notifyListeners();
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

  // ── Optimistic send ───────────────────────────────────────────────────────
  void sendMessage(
    String roomId,
    String content, {
    String? replyToId,
    required String senderId,
    required String senderUsername,
    required String senderColor,
    ReplyPreview? replyTo,
  }) {
    final clientId = 'pending_${DateTime.now().millisecondsSinceEpoch}';

    // 1. Insert optimistic message immediately
    final optimistic = Message(
      id: clientId, // use clientId as id until server confirms
      roomId: roomId,
      senderId: senderId,
      senderUsername: senderUsername,
      senderColor: senderColor,
      content: content,
      replyToId: replyToId,
      replyTo: replyTo,
      reactions: [],
      createdAt: DateTime.now(),
      status: MessageStatus.pending,
      clientId: clientId,
    );

    _msgs[roomId] = [...(_msgs[roomId] ?? []), optimistic];
    notifyListeners();

    // 2. Send via socket; server will broadcast back with real id + status
    socket.sendMessage(
      roomId: roomId,
      content: content,
      replyToId: replyToId,
      clientId: clientId,
    );
  }

  // ── Mark room as read ─────────────────────────────────────────────────────
  void markRoomRead(String roomId, String myUserId) {
    socket.markRoomRead(roomId);

    // Update local unread count immediately
    final idx = _rooms.indexWhere((r) => r.id == roomId);
    if (idx >= 0 && _rooms[idx].unreadCount > 0) {
      _rooms[idx] = _rooms[idx].copyWith(unreadCount: 0);
      notifyListeners();
    }
  }

  // ── Reactions ─────────────────────────────────────────────────────────────
  void toggleReaction(String messageId, String emoji, String myUsername) {
    for (final msgs in _msgs.values) {
      final msg = msgs.where((m) => m.id == messageId).firstOrNull;
      if (msg == null) continue;
      final alreadyReacted = msg.reactions
          .any((r) => r.emoji == emoji && r.users.contains(myUsername));
      if (alreadyReacted) {
        socket.removeReaction(messageId, emoji);
      } else {
        socket.addReaction(messageId, emoji);
      }
      break;
    }
  }

  // ── Typing ────────────────────────────────────────────────────────────────
  void sendTyping(String roomId, {required bool isTyping}) =>
      socket.sendTyping(roomId, isTyping: isTyping);

  // ── Room creation ─────────────────────────────────────────────────────────
  Future<Room> startDm(String targetUserId) async {
    final data = await api.createDm(targetUserId);
    final room = Room.fromJson(data);
    final idx = _rooms.indexWhere((r) => r.id == room.id);
    if (idx >= 0) return _rooms[idx];
    _rooms = [room, ..._rooms];
    notifyListeners();
    return room;
  }

  Future<Room> createGroup(String name, List<String> memberIds) async {
    final room = Room.fromJson(await api.createGroup(name, memberIds));
    _rooms = [room, ..._rooms];
    notifyListeners();
    return room;
  }

  Future<List<User>> allUsers() => api.getAllUsers();

  // ── Socket callbacks ───────────────────────────────────────────────────────
  void _onMessage(Message incoming) {
    final roomId = incoming.roomId;
    final list   = List<Message>.from(_msgs[roomId] ?? []);

    // Replace optimistic message if client_id matches
    final pendingIdx = incoming.clientId != null
        ? list.indexWhere((m) => m.clientId == incoming.clientId)
        : -1;

    if (pendingIdx >= 0) {
      list[pendingIdx] = incoming;
    } else {
      list.add(incoming);
    }
    _msgs[roomId] = list;

    // Update room preview
    final rIdx = _rooms.indexWhere((r) => r.id == roomId);
    if (rIdx >= 0) {
      final prev = _rooms[rIdx];
      _rooms[rIdx] = prev.copyWith(
        lastMessage: incoming.content,
        lastMessageAt: incoming.createdAt.toIso8601String(),
        lastMessageSender: incoming.senderUsername,
        // Only increment unread if we don't have an active listener (chat is closed)
        unreadCount: _msgListeners.containsKey(roomId)
            ? 0
            : prev.unreadCount + 1,
      );
    }

    _msgListeners[roomId]?.call();
    notifyListeners();
  }

  void _onReaction(String messageId, List<ReactionCount> reactions) {
    for (final roomId in _msgs.keys) {
      final idx = _msgs[roomId]!.indexWhere((m) => m.id == messageId);
      if (idx < 0) continue;
      final list  = List<Message>.from(_msgs[roomId]!);
      list[idx]   = list[idx].copyWith(reactions: reactions);
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

  void _onRoomReadBy(String roomId, String userId, DateTime readAt) {
    // Update status of messages sent BEFORE readAt to 'read'
    final list = _msgs[roomId];
    if (list == null) return;
    bool changed = false;
    final updated = list.map((m) {
      if (m.createdAt.isBefore(readAt) &&
          m.status != MessageStatus.read &&
          m.status != MessageStatus.pending) {
        changed = true;
        return m.copyWith(status: MessageStatus.read);
      }
      return m;
    }).toList();
    if (changed) {
      _msgs[roomId] = updated;
      notifyListeners();
    }
  }

  void _onPresence(String userId, bool online, DateTime? lastSeenDt) {
    _online[userId]   = online;
    if (!online && lastSeenDt != null) _lastSeen[userId] = lastSeenDt;
    notifyListeners();
  }

  void _onInitialPresence(Map<String, bool> onlineMap) {
    _online.addAll(onlineMap);
    notifyListeners();
  }
}
