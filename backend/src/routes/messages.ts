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

  if (!db.prepare('SELECT 1 FROM room_members WHERE room_id=? AND user_id=?').get(roomId, userId)) {
    res.status(403).json({ error: 'Not a member' }); return;
  }

  // Determine last-read time for this user in this room
  const readRow = db.prepare('SELECT last_read_at FROM room_reads WHERE room_id=? AND user_id=?')
    .get(roomId, userId) as { last_read_at: string } | undefined;
  const lastReadAt = readRow?.last_read_at ?? null;

  let query = `
    SELECT m.id, m.room_id, m.sender_id, m.content, m.reply_to_id, m.client_id,
           m.created_at, m.updated_at,
           u.username AS sender_username, u.avatar_color AS sender_color
    FROM messages m JOIN users u ON m.sender_id = u.id
    WHERE m.room_id = ?
  `;
  const params: (string | number)[] = [roomId];

  if (before) { query += ' AND m.created_at < ?'; params.push(before); }
  query += ' ORDER BY m.created_at DESC LIMIT ?';
  params.push(limit);

  const raw = db.prepare(query).all(...params) as (Message & { sender_username: string; sender_color: string })[];
  const ids = raw.map(m => m.id);
  const reactionsMap = getReactionsForMessages(ids);

  // Fetch reply previews
  const replyIds = [...new Set(raw.map(m => m.reply_to_id).filter(Boolean) as string[])];
  const replyMap = new Map<string, { id: string; sender_username: string; content: string }>();
  if (replyIds.length > 0) {
    const ph = replyIds.map(() => '?').join(',');
    const replies = db.prepare(`
      SELECT m.id, m.content, u.username AS sender_username
      FROM messages m JOIN users u ON m.sender_id = u.id WHERE m.id IN (${ph})
    `).all(...replyIds) as { id: string; content: string; sender_username: string }[];
    for (const r of replies) replyMap.set(r.id, r);
  }

  const messages: MessageWithMeta[] = raw.map(m => {
    // Determine per-message read status (for messages by others looking at my own messages from server perspective,
    // status = whether the room recipient has read past this point)
    let status: 'sent' | 'delivered' | 'read' = 'sent';
    if (lastReadAt && m.created_at <= lastReadAt) {
      status = 'read';
    }

    return {
      id: m.id,
      room_id: m.room_id,
      sender_id: m.sender_id,
      sender_username: m.sender_username,
      sender_color: m.sender_color,
      content: m.content,
      reply_to_id: m.reply_to_id,
      reply_to: m.reply_to_id ? replyMap.get(m.reply_to_id) ?? null : null,
      client_id: m.client_id,
      reactions: reactionsMap.get(m.id) ?? [],
      created_at: m.created_at,
      updated_at: m.updated_at,
      status,
    };
  });

  res.json(messages.reverse());
});

export default router;
