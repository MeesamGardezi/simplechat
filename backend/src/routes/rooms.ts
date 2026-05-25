import { Router, Request, Response } from 'express';
import { v4 as uuidv4 } from 'uuid';
import { getDb, getUnreadCount } from '../db';
import { authMiddleware } from '../middleware/auth';
import { User } from '../types';

const router = Router();
router.use(authMiddleware);

// ── List rooms ──────────────────────────────────────────────────────────────
router.get('/', (req: Request, res: Response): void => {
  const userId = (req as any).user.userId;
  const db = getDb();

  const rooms = db.prepare(`
    SELECT r.id, r.name, r.is_group, r.created_by, r.created_at,
           (SELECT content    FROM messages WHERE room_id = r.id ORDER BY created_at DESC LIMIT 1) AS last_message,
           (SELECT created_at FROM messages WHERE room_id = r.id ORDER BY created_at DESC LIMIT 1) AS last_message_at,
           (SELECT u2.username FROM messages m2 JOIN users u2 ON m2.sender_id = u2.id
            WHERE m2.room_id = r.id ORDER BY m2.created_at DESC LIMIT 1) AS last_message_sender
    FROM rooms r
    JOIN room_members rm ON r.id = rm.room_id
    WHERE rm.user_id = ?
    ORDER BY COALESCE(last_message_at, r.created_at) DESC
  `).all(userId) as any[];

  const result = rooms.map(room => {
    const unreadCount = getUnreadCount(room.id, userId);
    if (!room.is_group) {
      const other = db.prepare(`
        SELECT u.username, u.avatar_color, u.last_seen FROM users u
        JOIN room_members rm ON u.id = rm.user_id
        WHERE rm.room_id = ? AND u.id != ? LIMIT 1
      `).get(room.id, userId) as { username: string; avatar_color: string; last_seen: string | null } | undefined;

      return {
        ...room,
        name: other?.username ?? room.name,
        avatar_color: other?.avatar_color ?? '#075E54',
        other_last_seen: other?.last_seen ?? null,
        unread_count: unreadCount,
      };
    }
    return { ...room, avatar_color: '#075E54', unread_count: unreadCount };
  });

  res.json(result);
});

// ── Room members ─────────────────────────────────────────────────────────────
router.get('/:roomId/members', (req: Request, res: Response): void => {
  const userId = (req as any).user.userId;
  const { roomId } = req.params;
  const db = getDb();

  if (!db.prepare('SELECT 1 FROM room_members WHERE room_id=? AND user_id=?').get(roomId, userId)) {
    res.status(403).json({ error: 'Not a member' });
    return;
  }

  const members = db.prepare(`
    SELECT u.id, u.username, u.avatar_color, u.last_seen FROM users u
    JOIN room_members rm ON u.id = rm.user_id WHERE rm.room_id = ?
  `).all(roomId) as { id: string; username: string; avatar_color: string; last_seen: string | null }[];

  res.json(members);
});

// ── Create group ─────────────────────────────────────────────────────────────
router.post('/', (req: Request, res: Response): void => {
  const userId = (req as any).user.userId;
  const { name, member_ids } = req.body as { name: string; member_ids: string[] };

  if (!name?.trim()) { res.status(400).json({ error: 'Room name required' }); return; }

  const db = getDb();
  const id = uuidv4();

  db.prepare('INSERT INTO rooms (id,name,is_group,created_by) VALUES (?,?,1,?)').run(id, name.trim(), userId);
  db.prepare('INSERT INTO room_members (room_id,user_id) VALUES (?,?)').run(id, userId);

  for (const mid of [...new Set((member_ids || []).filter(m => m !== userId))]) {
    if (db.prepare('SELECT id FROM users WHERE id=?').get(mid)) {
      db.prepare('INSERT OR IGNORE INTO room_members (room_id,user_id) VALUES (?,?)').run(id, mid);
    }
  }

  res.status(201).json({ id, name: name.trim(), is_group: 1, avatar_color: '#075E54', created_by: userId, unread_count: 0 });
});

// ── Create / get DM ──────────────────────────────────────────────────────────
router.post('/dm', (req: Request, res: Response): void => {
  const userId = (req as any).user.userId;
  const { target_user_id } = req.body as { target_user_id: string };

  if (!target_user_id) { res.status(400).json({ error: 'target_user_id required' }); return; }

  const db = getDb();
  const target = db.prepare('SELECT id, username, avatar_color FROM users WHERE id=?')
    .get(target_user_id) as (User & { avatar_color: string }) | undefined;

  if (!target) { res.status(404).json({ error: 'User not found' }); return; }

  const existing = db.prepare(`
    SELECT r.id FROM rooms r
    JOIN room_members rm1 ON r.id=rm1.room_id AND rm1.user_id=?
    JOIN room_members rm2 ON r.id=rm2.room_id AND rm2.user_id=?
    WHERE r.is_group=0 LIMIT 1
  `).get(userId, target_user_id) as { id: string } | undefined;

  if (existing) {
    res.json({
      id: existing.id,
      name: target.username,
      is_group: 0,
      avatar_color: target.avatar_color ?? '#075E54',
      created_by: userId,
      unread_count: getUnreadCount(existing.id, userId),
      exists: true,
    });
    return;
  }

  const id = uuidv4();
  db.prepare('INSERT INTO rooms (id,name,is_group,created_by) VALUES (?,?,0,?)').run(id, `${userId}_${target_user_id}`, userId);
  db.prepare('INSERT INTO room_members (room_id,user_id) VALUES (?,?)').run(id, userId);
  db.prepare('INSERT INTO room_members (room_id,user_id) VALUES (?,?)').run(id, target_user_id);

  res.status(201).json({
    id,
    name: target.username,
    is_group: 0,
    avatar_color: target.avatar_color ?? '#075E54',
    created_by: userId,
    unread_count: 0,
    exists: false,
  });
});

// ── All users (for new chat) ─────────────────────────────────────────────────
router.get('/users/all', (req: Request, res: Response): void => {
  const userId = (req as any).user.userId;
  const db = getDb();

  const users = db.prepare(`
    SELECT id, username, avatar_color FROM users
    WHERE id != ? AND username != 'system' ORDER BY username
  `).all(userId) as { id: string; username: string; avatar_color: string }[];

  res.json(users);
});

export default router;
