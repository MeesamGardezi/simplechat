import { Router, Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import { v4 as uuidv4 } from 'uuid';
import { getDb } from '../db';
import { signToken } from '../middleware/auth';
import { User } from '../types';

const router = Router();

const AVATAR_COLORS = [
  '#075E54', '#128C7E', '#25D366', '#34B7F1',
  '#6B2D8B', '#E91E63', '#FF5722', '#FF9800',
  '#2196F3', '#009688', '#4CAF50', '#F44336',
];

router.post('/register', async (req: Request, res: Response): Promise<void> => {
  const { username, email, password } = req.body;

  if (!username || !email || !password) {
    res.status(400).json({ error: 'All fields are required' });
    return;
  }

  if (username.length < 2 || username.length > 24) {
    res.status(400).json({ error: 'Username must be 2-24 characters' });
    return;
  }

  if (password.length < 6) {
    res.status(400).json({ error: 'Password must be at least 6 characters' });
    return;
  }

  const db = getDb();

  const existing = db.prepare('SELECT id FROM users WHERE email = ? OR username = ?').get(email, username);
  if (existing) {
    res.status(409).json({ error: 'Email or username already taken' });
    return;
  }

  const password_hash = await bcrypt.hash(password, 10);
  const id = uuidv4();
  const avatar_color = AVATAR_COLORS[Math.floor(Math.random() * AVATAR_COLORS.length)];

  db.prepare(`
    INSERT INTO users (id, username, email, password_hash, avatar_color)
    VALUES (?, ?, ?, ?, ?)
  `).run(id, username, email, password_hash, avatar_color);

  // Auto-join general room
  const general = db.prepare("SELECT id FROM rooms WHERE name = 'General'").get() as { id: string } | undefined;
  if (general) {
    db.prepare('INSERT OR IGNORE INTO room_members (room_id, user_id) VALUES (?, ?)').run(general.id, id);
  }

  const token = signToken({ userId: id, username });
  res.status(201).json({ token, user: { id, username, email, avatar_color } });
});

router.post('/login', async (req: Request, res: Response): Promise<void> => {
  const { email, password } = req.body;

  if (!email || !password) {
    res.status(400).json({ error: 'Email and password required' });
    return;
  }

  const db = getDb();
  const user = db.prepare('SELECT * FROM users WHERE email = ?').get(email) as User | undefined;

  if (!user || !(await bcrypt.compare(password, user.password_hash))) {
    res.status(401).json({ error: 'Invalid credentials' });
    return;
  }

  const token = signToken({ userId: user.id, username: user.username });
  res.json({
    token,
    user: { id: user.id, username: user.username, email: user.email, avatar_color: user.avatar_color },
  });
});

export default router;
