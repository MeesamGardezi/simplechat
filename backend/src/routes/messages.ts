import { Router, Request, Response } from 'express';
import { getDb, getReactionsForMessages } from '../db';
import { authMiddleware } from '../middleware/auth';
import { Message, MessageWithMeta } from '../types';

const router = Router();
router.use(authMiddleware);

router.get('/:roomId', (req: Request, res: Response): void => {
  const userId = (req as any).user.userId;
  const { roomId } = req.params;
  const before = req.query.before as string | undefined;
  const limit = Math.min(Number(req.query.limit) || 50, 100);

  const db = getDb();

  const member = db.prepare('SELECT 1 FROM room_members WHERE room_id = ? AND user_id = ?').get(roomId, userId);
  if (!member) {
    res.status(403).json({ error: 'Not a member of this room' });
    return;
  }

  let query = `
    SELECT m.id, m.room_id, m.sender_id, m.content, m.reply_to_id, m.created_at, m.updated_at,
           u.username AS sender_username, u.avatar_color AS sender_color
    FROM messages m
    JOIN users u ON m.sender_id = u.id
    WHERE m.room_id = ?
  `;
  const params: (string | number)[] = [roomId];

  if (before) {
    query += ' AND m.created_at < ?';
    params.push(before);
  }

  query += ' ORDER BY m.created_at DESC LIMIT ?';
  params.push(limit);

  const rawMessages = db.prepare(query).all(...params) as (Message & { sender_username: string; sender_color: string })[];
  const messageIds = rawMessages.map(m => m.id);
  const reactionsMap = getReactionsForMessages(messageIds);

  // Fetch reply previews
  const replyIds = rawMessages.map(m => m.reply_to_id).filter(Boolean) as string[];
  const replyMap = new Map<string, { id: string; sender_username: string; content: string }>();
  if (replyIds.length > 0) {
    const placeholders = replyIds.map(() => '?').join(',');
    const replies = db.prepare(`
      SELECT m.id, m.content, u.username AS sender_username
      FROM messages m JOIN users u ON m.sender_id = u.id
      WHERE m.id IN (${placeholders})
    `).all(...replyIds) as { id: string; content: string; sender_username: string }[];
    for (const r of replies) replyMap.set(r.id, r);
  }

  const messages: MessageWithMeta[] = rawMessages.map(m => ({
    id: m.id,
    room_id: m.room_id,
    sender_id: m.sender_id,
    sender_username: m.sender_username,
    sender_color: m.sender_color,
    content: m.content,
    reply_to_id: m.reply_to_id,
    reply_to: m.reply_to_id ? replyMap.get(m.reply_to_id) ?? null : null,
    created_at: m.created_at,
    updated_at: m.updated_at,
    reactions: reactionsMap.get(m.id) ?? [],
  }));

  // Return in chronological order
  res.json(messages.reverse());
});

export default router;
