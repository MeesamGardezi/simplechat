import { Server, Socket } from 'socket.io';
import jwt from 'jsonwebtoken';
import { v4 as uuidv4 } from 'uuid';
import { getDb, getReactionsForMessages, markRoomRead } from '../db';
import { JwtPayload, Message, MessageWithMeta } from '../types';

const JWT_SECRET = process.env.JWT_SECRET || 'simplechat-secret-key-change-in-prod';

// In-memory online presence: userId → {username, socketId}
const online = new Map<string, { username: string; socketId: string }>();

interface AuthSocket extends Socket {
  userId: string;
  username: string;
}

function buildMessage(raw: Message & { sender_username: string; sender_color: string }): MessageWithMeta {
  const db = getDb();
  const reactionsMap = getReactionsForMessages([raw.id]);

  let replyTo = null;
  if (raw.reply_to_id) {
    replyTo = db.prepare(`
      SELECT m.id, m.content, u.username AS sender_username
      FROM messages m JOIN users u ON m.sender_id = u.id WHERE m.id = ?
    `).get(raw.reply_to_id) as { id: string; content: string; sender_username: string } | undefined ?? null;
  }

  return {
    id: raw.id,
    room_id: raw.room_id,
    sender_id: raw.sender_id,
    sender_username: raw.sender_username,
    sender_color: raw.sender_color,
    content: raw.content,
    reply_to_id: raw.reply_to_id,
    reply_to: replyTo,
    client_id: raw.client_id,
    reactions: reactionsMap.get(raw.id) ?? [],
    created_at: raw.created_at,
    updated_at: raw.updated_at,
    status: 'sent',
  };
}

export function registerSocketHandlers(io: Server): void {

  // ── Auth middleware ──────────────────────────────────────────────────────
  io.use((socket, next) => {
    const token = socket.handshake.auth.token;
    if (!token) return next(new Error('Authentication required'));
    try {
      const p = jwt.verify(token, JWT_SECRET) as JwtPayload;
      (socket as AuthSocket).userId = p.userId;
      (socket as AuthSocket).username = p.username;
      next();
    } catch {
      next(new Error('Invalid token'));
    }
  });

  io.on('connection', rawSocket => {
    const socket = rawSocket as AuthSocket;
    const db = getDb();

    // Register online
    online.set(socket.userId, { username: socket.username, socketId: socket.id });

    // Join all user rooms
    const userRooms = db.prepare('SELECT room_id FROM room_members WHERE user_id=?')
      .all(socket.userId) as { room_id: string }[];

    for (const { room_id } of userRooms) {
      socket.join(room_id);
    }

    // Broadcast user is now online to all their rooms
    for (const { room_id } of userRooms) {
      socket.to(room_id).emit('presence_update', {
        user_id: socket.userId,
        username: socket.username,
        online: true,
      });
    }

    // Send current online list of room members back to this socket
    const onlineInMyRooms: Record<string, boolean> = {};
    for (const { room_id } of userRooms) {
      const members = db.prepare('SELECT user_id FROM room_members WHERE room_id=?')
        .all(room_id) as { user_id: string }[];
      for (const m of members) {
        if (online.has(m.user_id)) onlineInMyRooms[m.user_id] = true;
      }
    }
    socket.emit('initial_presence', onlineInMyRooms);

    // ── join_room ────────────────────────────────────────────────────────
    socket.on('join_room', ({ room_id }: { room_id: string }) => {
      const isMember = db.prepare('SELECT 1 FROM room_members WHERE room_id=? AND user_id=?')
        .get(room_id, socket.userId);
      if (isMember) socket.join(room_id);
    });

    // ── send_message ─────────────────────────────────────────────────────
    socket.on('send_message', ({
      room_id, content, reply_to_id, client_id,
    }: { room_id: string; content: string; reply_to_id?: string; client_id?: string }) => {
      if (!content?.trim()) return;

      const isMember = db.prepare('SELECT 1 FROM room_members WHERE room_id=? AND user_id=?')
        .get(room_id, socket.userId);
      if (!isMember) { socket.emit('error', { message: 'Not a member' }); return; }

      const id = uuidv4();
      const now = new Date().toISOString();
      const sender = db.prepare('SELECT avatar_color FROM users WHERE id=?')
        .get(socket.userId) as { avatar_color: string };

      db.prepare(`
        INSERT INTO messages (id,room_id,sender_id,content,reply_to_id,client_id,created_at,updated_at)
        VALUES (?,?,?,?,?,?,?,?)
      `).run(id, room_id, socket.userId, content.trim(), reply_to_id ?? null, client_id ?? null, now, now);

      const raw = {
        id, room_id, sender_id: socket.userId, content: content.trim(),
        reply_to_id: reply_to_id ?? null, client_id: client_id ?? null,
        created_at: now, updated_at: now,
        sender_username: socket.username, sender_color: sender.avatar_color,
      } as Message & { sender_username: string; sender_color: string };

      const msg = buildMessage(raw);

      // Check how many other members are currently online → determines initial status
      const roomMembers = db.prepare('SELECT user_id FROM room_members WHERE room_id=? AND user_id!=?')
        .all(room_id, socket.userId) as { user_id: string }[];
      const hasOnlineRecipient = roomMembers.some(m => online.has(m.user_id));

      const outMsg = { ...msg, status: hasOnlineRecipient ? 'delivered' : 'sent' };

      // Broadcast to room (includes sender so their optimistic msg gets replaced)
      io.to(room_id).emit('new_message', outMsg);
    });

    // ── mark_room_read ───────────────────────────────────────────────────
    socket.on('mark_room_read', ({ room_id }: { room_id: string }) => {
      const isMember = db.prepare('SELECT 1 FROM room_members WHERE room_id=? AND user_id=?')
        .get(room_id, socket.userId);
      if (!isMember) return;

      markRoomRead(room_id, socket.userId);

      // Tell senders in this room that their messages have been read
      socket.to(room_id).emit('room_read_by', {
        room_id,
        user_id: socket.userId,
        username: socket.username,
        read_at: new Date().toISOString(),
      });
    });

    // ── add_reaction ─────────────────────────────────────────────────────
    socket.on('add_reaction', ({ message_id, emoji }: { message_id: string; emoji: string }) => {
      const msg = db.prepare('SELECT room_id FROM messages WHERE id=?')
        .get(message_id) as { room_id: string } | undefined;
      if (!msg) return;

      if (!db.prepare('SELECT 1 FROM room_members WHERE room_id=? AND user_id=?').get(msg.room_id, socket.userId)) return;

      try {
        db.prepare('INSERT OR IGNORE INTO reactions (id,message_id,user_id,emoji) VALUES (?,?,?,?)')
          .run(uuidv4(), message_id, socket.userId, emoji);
      } catch { return; }

      const map = getReactionsForMessages([message_id]);
      io.to(msg.room_id).emit('reaction_updated', { message_id, reactions: map.get(message_id) ?? [] });
    });

    // ── remove_reaction ──────────────────────────────────────────────────
    socket.on('remove_reaction', ({ message_id, emoji }: { message_id: string; emoji: string }) => {
      const msg = db.prepare('SELECT room_id FROM messages WHERE id=?')
        .get(message_id) as { room_id: string } | undefined;
      if (!msg) return;

      db.prepare('DELETE FROM reactions WHERE message_id=? AND user_id=? AND emoji=?')
        .run(message_id, socket.userId, emoji);

      const map = getReactionsForMessages([message_id]);
      io.to(msg.room_id).emit('reaction_updated', { message_id, reactions: map.get(message_id) ?? [] });
    });

    // ── typing ───────────────────────────────────────────────────────────
    socket.on('typing', ({ room_id, is_typing }: { room_id: string; is_typing: boolean }) => {
      if (!db.prepare('SELECT 1 FROM room_members WHERE room_id=? AND user_id=?').get(room_id, socket.userId)) return;
      socket.to(room_id).emit('user_typing', {
        user_id: socket.userId, username: socket.username, room_id, is_typing,
      });
    });

    // ── disconnect ───────────────────────────────────────────────────────
    socket.on('disconnect', () => {
      online.delete(socket.userId);
      const now = new Date().toISOString();
      db.prepare('UPDATE users SET last_seen=? WHERE id=?').run(now, socket.userId);

      for (const { room_id } of userRooms) {
        io.to(room_id).emit('presence_update', {
          user_id: socket.userId,
          username: socket.username,
          online: false,
          last_seen: now,
        });
        // Clear typing indicator on disconnect
        socket.to(room_id).emit('user_typing', {
          user_id: socket.userId, username: socket.username, room_id, is_typing: false,
        });
      }
    });
  });
}
