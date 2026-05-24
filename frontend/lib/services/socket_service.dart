import 'package:socket_io_client/socket_io_client.dart' as io;
import '../models/message.dart';

typedef MessageCallback = void Function(Message message);
typedef ReactionCallback = void Function(String messageId, List<ReactionCount> reactions);
typedef TypingCallback = void Function(String userId, String username, String roomId, bool isTyping);

class SocketService {
  io.Socket? _socket;
  final String serverUrl;

  MessageCallback? onNewMessage;
  ReactionCallback? onReactionUpdated;
  TypingCallback? onUserTyping;

  SocketService({required this.serverUrl});

  bool get isConnected => _socket?.connected ?? false;

  void connect(String token) {
    // Always clean up the old socket before creating a new one
    _socket?.clearListeners();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;

    _socket = io.io(serverUrl, io.OptionBuilder()
        .setTransports(['websocket'])
        .setAuth({'token': token})
        .enableAutoConnect()
        .enableReconnection()
        .setReconnectionAttempts(10)
        .setReconnectionDelay(1000)
        .build());

    _socket!.on('new_message', (data) {
      if (data is Map<String, dynamic>) {
        onNewMessage?.call(Message.fromJson(data));
      }
    });

    _socket!.on('reaction_updated', (data) {
      if (data is Map<String, dynamic>) {
        final messageId = data['message_id'] as String;
        final reactions = (data['reactions'] as List<dynamic>? ?? [])
            .map((r) => ReactionCount.fromJson(r as Map<String, dynamic>))
            .toList();
        onReactionUpdated?.call(messageId, reactions);
      }
    });

    _socket!.on('user_typing', (data) {
      if (data is Map<String, dynamic>) {
        onUserTyping?.call(
          data['user_id'] as String,
          data['username'] as String,
          data['room_id'] as String,
          data['is_typing'] as bool,
        );
      }
    });
  }

  void joinRoom(String roomId) => _socket?.emit('join_room', {'room_id': roomId});

  void sendMessage({required String roomId, required String content, String? replyToId}) {
    _socket?.emit('send_message', {
      'room_id': roomId,
      'content': content,
      if (replyToId != null) 'reply_to_id': replyToId,
    });
  }

  void addReaction(String messageId, String emoji) =>
      _socket?.emit('add_reaction', {'message_id': messageId, 'emoji': emoji});

  void removeReaction(String messageId, String emoji) =>
      _socket?.emit('remove_reaction', {'message_id': messageId, 'emoji': emoji});

  void sendTyping(String roomId, {required bool isTyping}) =>
      _socket?.emit('typing', {'room_id': roomId, 'is_typing': isTyping});

  void disconnect() {
    _socket?.clearListeners();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
