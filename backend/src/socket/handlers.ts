import { Server, Socket } from 'socket.io';
import jwt from 'jsonwebtoken';
import { v4 as uuidv4 } from 'uuid';
import { getDb, getReactionsForMessages } from '../db';
import { JwtPayload, Message, MessageWithMeta } from '../types';

const JWT_SECRET = process.env.JWT_SECRET || 'simplechat-secret-key-change-in-prod';

interface AuthSocket extends Socket {
  userId: string;
  username: string;
}

export function registerSocketHandlers(io: Server): void {
  // Auth middleware for socket
  io.use((socket, next) => {
    const token = socket.handshake.auth.token;
    if (!token) return next(new Error('Authentication required'));

    try {
      const payload = jwt.verify(token, JWT_SECRET) as JwtPayload;
      (socket as AuthSocket).userId = payload.userId;
      (socket as AuthSocket).username = payload.username;
      next();
    } catch {
      next(new Error('Invalid token'));
    }
  });

  io.on('connection', (rawSocket) => {
    const socket = rawSocket as AuthSocket;
    const db = getDb();

    // Auto-join all user rooms
    const userRooms = db.prepare('SELECT room_id FROM room_members WHERE user_id = ?').all(socket.userId) as { room_id: string }[];
    for (const { room_id } of userRooms) {
      socket.join(room_id);
    }

    socket.on('join_room', ({ room_id }: { room_id: string }) => {
      const isMember = db.prepare('SELECT 1 FROM room_members WHERE room_id = ? AND user_id = ?').get(room_id, socket.userId);
      if (isMember) socket.join(room_id);
    });

    socket.on('send_message', ({ room_id, content, reply_to_id }: { room_id: string; content: string; reply_to_id?: string }) => {
      if (!content?.trim()) return;

      const isMember = db.prepare('SELECT 1 FROM room_members WHERE room_id = ? AND user_id = ?').get(room_id, socket.userId);
      if (!isMember) {
        socket.emit('error', { message: 'Not a member of this room' });
        return;
      }

      const id = uuidv4();
      const now = new Date().toISOString();

      db.prepare(`
        INSERT INTO messages (id, room_id, sender_id, content, reply_to_id, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      `).run(id, room_id, socket.userId, content.trim(), reply_to_id ?? null, now, now);

      const sender = db.prepare('SELECT avatar_color FROM users WHERE id = ?').get(socket.userId) as { avatar_color: string };

      let replyPreview = null;
      if (reply_to_id) {
        const reply = db.prepare(`
          SELECT m.id, m.content, u.username AS sender_username
          FROM messages m JOIN users u ON m.sender_id = u.id
          WHERE m.id = ?
        `).get(reply_to_id) as { id: string; content: string; sender_username: string } | undefined;
        replyPreview = reply ?? null;
      }

      const message: MessageWithMeta = {
        id,
        room_id,
        sender_id: socket.userId,
        sender_username: socket.username,
        sender_color: sender.avatar_color,
        content: content.trim(),
        reply_to_id: reply_to_id ?? null,
        reply_to: replyPreview,
        created_at: now,
        updated_at: now,
        reactions: [],
      };

      io.to(room_id).emit('new_message', message);
    });

    socket.on('add_reaction', ({ message_id, emoji }: { message_id: string; emoji: string }) => {
      const message = db.prepare('SELECT room_id FROM messages WHERE id = ?').get(message_id) as { room_id: string } | undefined;
      if (!message) return;

      const isMember = db.prepare('SELECT 1 FROM room_members WHERE room_id = ? AND user_id = ?').get(message.room_id, socket.userId);
      if (!isMember) return;

      const id = uuidv4();
      try {
        db.prepare('INSERT OR IGNORE INTO reactions (id, message_id, user_id, emoji) VALUES (?, ?, ?, ?)').run(id, message_id, socket.userId, emoji);
      } catch {
        return;
      }

      const reactionsMap = getReactionsForMessages([message_id]);
      io.to(message.room_id).emit('reaction_updated', {
        message_id,
        reactions: reactionsMap.get(message_id) ?? [],
      });
    });

    socket.on('remove_reaction', ({ message_id, emoji }: { message_id: string; emoji: string }) => {
      const message = db.prepare('SELECT room_id FROM messages WHERE id = ?').get(message_id) as { room_id: string } | undefined;
      if (!message) return;

      db.prepare('DELETE FROM reactions WHERE message_id = ? AND user_id = ? AND emoji = ?').run(message_id, socket.userId, emoji);

      const reactionsMap = getReactionsForMessages([message_id]);
      io.to(message.room_id).emit('reaction_updated', {
        message_id,
        reactions: reactionsMap.get(message_id) ?? [],
      });
    });

    socket.on('typing', ({ room_id, is_typing }: { room_id: string; is_typing: boolean }) => {
      const isMember = db.prepare('SELECT 1 FROM room_members WHERE room_id = ? AND user_id = ?').get(room_id, socket.userId);
      if (!isMember) return;

      socket.to(room_id).emit('user_typing', {
        user_id: socket.userId,
        username: socket.username,
        room_id,
        is_typing,
      });
    });

    socket.on('disconnect', () => {
      // Notify all rooms this user was in that they're offline
      for (const { room_id } of userRooms) {
        socket.to(room_id).emit('user_typing', {
          user_id: socket.userId,
          username: socket.username,
          room_id,
          is_typing: false,
        });
      }
    });
  });
}
