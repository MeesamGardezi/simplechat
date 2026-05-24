import { Router, Request, Response } from 'express';
import { v4 as uuidv4 } from 'uuid';
import { getDb } from '../db';
import { authMiddleware } from '../middleware/auth';
import { Room, User } from '../types';

const router = Router();
router.use(authMiddleware);

// Get all rooms for the current user
router.get('/', (req: Request, res: Response): void => {
  const userId = (req as any).user.userId;
  const db = getDb();

  const rooms = db.prepare(`
    SELECT r.id, r.name, r.is_group, r.created_by, r.created_at,
           (SELECT content FROM messages WHERE room_id = r.id ORDER BY created_at DESC LIMIT 1) AS last_message,
           (SELECT created_at FROM messages WHERE room_id = r.id ORDER BY created_at DESC LIMIT 1) AS last_message_at
    FROM rooms r
    JOIN room_members rm ON r.id = rm.room_id
    WHERE rm.user_id = ?
    ORDER BY COALESCE(last_message_at, r.created_at) DESC
  `).all(userId) as (Room & { last_message: string; last_message_at: string })[];

  // For DMs, use the other person's name
  const result = rooms.map(room => {
    if (!room.is_group) {
      const other = db.prepare(`
        SELECT u.username, u.avatar_color FROM users u
        JOIN room_members rm ON u.id = rm.user_id
        WHERE rm.room_id = ? AND u.id != ?
        LIMIT 1
      `).get(room.id, userId) as { username: string; avatar_color: string } | undefined;

      return {
        ...room,
        name: other?.username ?? room.name,
        avatar_color: other?.avatar_color ?? '#075E54',
      };
    }
    return { ...room, avatar_color: '#075E54' };
  });

  res.json(result);
});

// Get room members
router.get('/:roomId/members', (req: Request, res: Response): void => {
  const userId = (req as any).user.userId;
  const { roomId } = req.params;
  const db = getDb();

  const member = db.prepare('SELECT 1 FROM room_members WHERE room_id = ? AND user_id = ?').get(roomId, userId);
  if (!member) {
    res.status(403).json({ error: 'Not a member' });
    return;
  }

  const members = db.prepare(`
    SELECT u.id, u.username, u.avatar_color FROM users u
    JOIN room_members rm ON u.id = rm.user_id
    WHERE rm.room_id = ?
  `).all(roomId) as { id: string; username: string; avatar_color: string }[];

  res.json(members);
});

// Create a group room
router.post('/', (req: Request, res: Response): void => {
  const userId = (req as any).user.userId;
  const { name, member_ids } = req.body as { name: string; member_ids: string[] };

  if (!name || !name.trim()) {
    res.status(400).json({ error: 'Room name required' });
    return;
  }

  const db = getDb();
  const id = uuidv4();

  db.prepare('INSERT INTO rooms (id, name, is_group, created_by) VALUES (?, ?, 1, ?)').run(id, name.trim(), userId);
  db.prepare('INSERT INTO room_members (room_id, user_id) VALUES (?, ?)').run(id, userId);

  const uniqueMembers = [...new Set(member_ids || [])].filter(mid => mid !== userId);
  for (const memberId of uniqueMembers) {
    const userExists = db.prepare('SELECT id FROM users WHERE id = ?').get(memberId);
    if (userExists) {
      db.prepare('INSERT OR IGNORE INTO room_members (room_id, user_id) VALUES (?, ?)').run(id, memberId);
    }
  }

  res.status(201).json({ id, name: name.trim(), is_group: 1, created_by: userId });
});

// Create or get a DM room
router.post('/dm', (req: Request, res: Response): void => {
  const userId = (req as any).user.userId;
  const { target_user_id } = req.body as { target_user_id: string };

  if (!target_user_id) {
    res.status(400).json({ error: 'target_user_id required' });
    return;
  }

  const db = getDb();

  const targetUser = db.prepare('SELECT id, username FROM users WHERE id = ?').get(target_user_id) as User | undefined;
  if (!targetUser) {
    res.status(404).json({ error: 'User not found' });
    return;
  }

  // Check if DM already exists
  const existing = db.prepare(`
    SELECT r.id FROM rooms r
    JOIN room_members rm1 ON r.id = rm1.room_id AND rm1.user_id = ?
    JOIN room_members rm2 ON r.id = rm2.room_id AND rm2.user_id = ?
    WHERE r.is_group = 0
    LIMIT 1
  `).get(userId, target_user_id) as { id: string } | undefined;

  if (existing) {
    res.json({ id: existing.id, exists: true });
    return;
  }

  const me = db.prepare('SELECT username FROM users WHERE id = ?').get(userId) as { username: string };
  const id = uuidv4();
  const name = `${me.username}_${targetUser.username}`;

  db.prepare('INSERT INTO rooms (id, name, is_group, created_by) VALUES (?, ?, 0, ?)').run(id, name, userId);
  db.prepare('INSERT INTO room_members (room_id, user_id) VALUES (?, ?)').run(id, userId);
  db.prepare('INSERT INTO room_members (room_id, user_id) VALUES (?, ?)').run(id, target_user_id);

  res.status(201).json({ id, name, is_group: 0, exists: false });
});

// List all users (for starting DMs)
router.get('/users/all', (req: Request, res: Response): void => {
  const userId = (req as any).user.userId;
  const db = getDb();

  const users = db.prepare(`
    SELECT id, username, avatar_color FROM users
    WHERE id != ? AND username != 'system'
    ORDER BY username
  `).all(userId) as { id: string; username: string; avatar_color: string }[];

  res.json(users);
});

export default router;
