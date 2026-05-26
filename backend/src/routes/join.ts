import { Router, Request, Response } from 'express';
import { v4 as uuidv4 } from 'uuid';
import { getDb } from '../db';
import { signToken } from '../middleware/auth';

const router = Router();

const AVATAR_COLORS = [
  '#E53935', '#8E24AA', '#1E88E5', '#00897B',
  '#F4511E', '#6D4C41', '#039BE5', '#7CB342',
  '#C0CA33', '#FB8C00', '#3949AB', '#D81B60',
];

router.post('/join', (req: Request, res: Response): void => {
  const name = (req.body?.name ?? '').toString().trim();

  if (name.length < 2 || name.length > 24) {
    res.status(400).json({ error: 'Name must be 2–24 characters' });
    return;
  }
  if (!/^[a-zA-Z0-9_ ]+$/.test(name)) {
    res.status(400).json({ error: 'Letters, numbers, spaces and underscores only' });
    return;
  }

  const db = getDb();
  const existing = db.prepare('SELECT id, username, avatar_color FROM users WHERE username = ?').get(name) as
    | { id: string; username: string; avatar_color: string }
    | undefined;

  if (existing) {
    res.status(409).json({ error: 'That name is taken — try another' });
    return;
  }

  const id = uuidv4();
  const avatarColor = AVATAR_COLORS[Math.floor(Math.random() * AVATAR_COLORS.length)];

  db.prepare(`
    INSERT INTO users (id, username, email, password_hash, avatar_color)
    VALUES (?, ?, ?, 'none', ?)
  `).run(id, name, `${id}@simplechat.local`, avatarColor);

  const general = db.prepare("SELECT id FROM rooms WHERE name = 'General'").get() as { id: string } | undefined;
  if (general) {
    db.prepare('INSERT OR IGNORE INTO room_members (room_id, user_id) VALUES (?, ?)').run(general.id, id);
  }

  const token = signToken({ userId: id, username: name });
  res.status(201).json({ token, user: { id, username: name, avatar_color: avatarColor } });
});

export default router;
