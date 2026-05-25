import Database from 'better-sqlite3';
import path from 'path';
import { v4 as uuidv4 } from 'uuid';

const DB_PATH = path.join(__dirname, '..', 'data', 'simplechat.db');
let db: Database.Database;

export function getDb(): Database.Database {
  if (!db) {
    const fs = require('fs');
    fs.mkdirSync(path.dirname(DB_PATH), { recursive: true });
    db = new Database(DB_PATH);
    db.pragma('journal_mode = WAL');
    db.pragma('foreign_keys = ON');
    initSchema();
  }
  return db;
}

function initSchema(): void {
  db.exec(`
    CREATE TABLE IF NOT EXISTS users (
      id           TEXT PRIMARY KEY,
      username     TEXT UNIQUE NOT NULL,
      email        TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      avatar_color TEXT NOT NULL DEFAULT '#075E54',
      last_seen    TEXT,
      created_at   TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS rooms (
      id         TEXT PRIMARY KEY,
      name       TEXT NOT NULL,
      is_group   INTEGER NOT NULL DEFAULT 0,
      created_by TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      FOREIGN KEY (created_by) REFERENCES users(id)
    );

    CREATE TABLE IF NOT EXISTS room_members (
      room_id   TEXT NOT NULL,
      user_id   TEXT NOT NULL,
      joined_at TEXT NOT NULL DEFAULT (datetime('now')),
      PRIMARY KEY (room_id, user_id),
      FOREIGN KEY (room_id) REFERENCES rooms(id),
      FOREIGN KEY (user_id) REFERENCES users(id)
    );

    CREATE TABLE IF NOT EXISTS messages (
      id          TEXT PRIMARY KEY,
      room_id     TEXT NOT NULL,
      sender_id   TEXT NOT NULL,
      content     TEXT NOT NULL,
      reply_to_id TEXT,
      client_id   TEXT,
      created_at  TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at  TEXT NOT NULL DEFAULT (datetime('now')),
      FOREIGN KEY (room_id)     REFERENCES rooms(id),
      FOREIGN KEY (sender_id)   REFERENCES users(id),
      FOREIGN KEY (reply_to_id) REFERENCES messages(id)
    );

    CREATE TABLE IF NOT EXISTS reactions (
      id         TEXT PRIMARY KEY,
      message_id TEXT NOT NULL,
      user_id    TEXT NOT NULL,
      emoji      TEXT NOT NULL,
      UNIQUE(message_id, user_id, emoji),
      FOREIGN KEY (message_id) REFERENCES messages(id),
      FOREIGN KEY (user_id)    REFERENCES users(id)
    );

    -- Track last-read position per user per room (for unread counts + read receipts)
    CREATE TABLE IF NOT EXISTS room_reads (
      room_id     TEXT NOT NULL,
      user_id     TEXT NOT NULL,
      last_read_at TEXT NOT NULL DEFAULT (datetime('now')),
      PRIMARY KEY (room_id, user_id),
      FOREIGN KEY (room_id)  REFERENCES rooms(id),
      FOREIGN KEY (user_id)  REFERENCES users(id)
    );
  `);

  // Safe column migrations for existing databases
  for (const migration of [
    "ALTER TABLE users    ADD COLUMN last_seen  TEXT",
    "ALTER TABLE messages ADD COLUMN client_id  TEXT",
  ]) {
    try { db.exec(migration); } catch { /* already exists */ }
  }

  // Seed General room
  const generalExists = db.prepare("SELECT id FROM rooms WHERE name='General'").get();
  if (!generalExists) {
    const sysId = uuidv4();
    const genId = uuidv4();
    db.prepare(`INSERT OR IGNORE INTO users (id,username,email,password_hash,avatar_color)
                VALUES (?,'system','system@simplechat.app','disabled','#075E54')`).run(sysId);
    db.prepare(`INSERT INTO rooms (id,name,is_group,created_by) VALUES (?,'General',1,?)`).run(genId, sysId);
  }
}

export function getReactionsForMessages(messageIds: string[]): Map<string, ReactionEntry[]> {
  const map = new Map<string, ReactionEntry[]>();
  if (messageIds.length === 0) return map;

  const ph = messageIds.map(() => '?').join(',');
  const rows = getDb().prepare(`
    SELECT r.message_id, r.emoji, u.username
    FROM   reactions r JOIN users u ON r.user_id = u.id
    WHERE  r.message_id IN (${ph})
    ORDER  BY r.message_id, r.emoji
  `).all(...messageIds) as { message_id: string; emoji: string; username: string }[];

  for (const row of rows) {
    if (!map.has(row.message_id)) map.set(row.message_id, []);
    const list = map.get(row.message_id)!;
    const ex = list.find(r => r.emoji === row.emoji);
    if (ex) { ex.count++; ex.users.push(row.username); }
    else      list.push({ emoji: row.emoji, count: 1, users: [row.username] });
  }
  return map;
}

interface ReactionEntry { emoji: string; count: number; users: string[] }

export function getUnreadCount(roomId: string, userId: string): number {
  const row = getDb().prepare(`
    SELECT COUNT(*) AS cnt FROM messages m
    LEFT JOIN room_reads rr ON rr.room_id = m.room_id AND rr.user_id = ?
    WHERE m.room_id = ?
      AND m.sender_id != ?
      AND (rr.last_read_at IS NULL OR m.created_at > rr.last_read_at)
  `).get(userId, roomId, userId) as { cnt: number };
  return row.cnt;
}

export function markRoomRead(roomId: string, userId: string): void {
  getDb().prepare(`
    INSERT INTO room_reads (room_id, user_id, last_read_at)
    VALUES (?, ?, datetime('now'))
    ON CONFLICT(room_id, user_id) DO UPDATE SET last_read_at = datetime('now')
  `).run(roomId, userId);
}
