import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../models/message.dart';

typedef MessageCallback       = void Function(Message message);
typedef ReactionCallback      = void Function(String messageId, List<ReactionCount> reactions);
typedef TypingCallback        = void Function(String userId, String username, String roomId, bool isTyping);
typedef RoomReadCallback      = void Function(String roomId, String userId, DateTime readAt);
typedef PresenceCallback      = void Function(String userId, bool online, DateTime? lastSeen);
typedef InitPresenceCallback  = void Function(Map<String, bool> onlineMap);

class SocketService {
  final String serverUrl;
  io.Socket? _socket;

  final connected = ValueNotifier<bool>(false);

  MessageCallback?      onNewMessage;
  ReactionCallback?     onReactionUpdated;
  TypingCallback?       onUserTyping;
  RoomReadCallback?     onRoomReadBy;
  PresenceCallback?     onPresenceUpdate;
  InitPresenceCallback? onInitialPresence;

  SocketService({required this.serverUrl});

  void connect(String token) {
    _socket?.clearListeners();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;

    _socket = io.io(
      serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(1 << 20) // effectively infinite
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .build(),
    );

    _socket!
      ..on('connect',    (_) { connected.value = true;  })
      ..on('disconnect', (_) { connected.value = false; })
      ..on('connect_error', (_) { connected.value = false; })

      ..on('new_message', (d) {
        if (d is Map<String, dynamic>) onNewMessage?.call(Message.fromJson(d));
      })

      ..on('reaction_updated', (d) {
        if (d is Map<String, dynamic>) {
          final reactions = (d['reactions'] as List<dynamic>? ?? [])
              .map((r) => ReactionCount.fromJson(r as Map<String, dynamic>))
              .toList();
          onReactionUpdated?.call(d['message_id'] as String, reactions);
        }
      })

      ..on('user_typing', (d) {
        if (d is Map<String, dynamic>) {
          onUserTyping?.call(
            d['user_id'] as String,
            d['username'] as String,
            d['room_id'] as String,
            d['is_typing'] as bool,
          );
        }
      })

      ..on('room_read_by', (d) {
        if (d is Map<String, dynamic>) {
          onRoomReadBy?.call(
            d['room_id'] as String,
            d['user_id'] as String,
            DateTime.parse(d['read_at'] as String),
          );
        }
      })

      ..on('presence_update', (d) {
        if (d is Map<String, dynamic>) {
          final lastSeenStr = d['last_seen'] as String?;
          onPresenceUpdate?.call(
            d['user_id'] as String,
            d['online'] as bool,
            lastSeenStr != null ? DateTime.tryParse(lastSeenStr) : null,
          );
        }
      })

      ..on('initial_presence', (d) {
        if (d is Map<String, dynamic>) {
          final map = d.map((k, v) => MapEntry(k, v as bool));
          onInitialPresence?.call(map);
        }
      });
  }

  void joinRoom(String roomId)    => _emit('join_room',       {'room_id': roomId});
  void markRoomRead(String roomId) => _emit('mark_room_read', {'room_id': roomId});

  void sendMessage({
    required String roomId,
    required String content,
    String? replyToId,
    String? clientId,
  }) =>
      _emit('send_message', {
        'room_id': roomId,
        'content': content,
        if (replyToId != null) 'reply_to_id': replyToId,
        if (clientId != null) 'client_id': clientId,
      });

  void addReaction(String messageId, String emoji) =>
      _emit('add_reaction',    {'message_id': messageId, 'emoji': emoji});

  void removeReaction(String messageId, String emoji) =>
      _emit('remove_reaction', {'message_id': messageId, 'emoji': emoji});

  void sendTyping(String roomId, {required bool isTyping}) =>
      _emit('typing', {'room_id': roomId, 'is_typing': isTyping});

  void _emit(String event, Map<String, dynamic> data) {
    _socket?.emit(event, data);
  }

  void disconnect() {
    _socket?.clearListeners();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    connected.value = false;
  }
}
