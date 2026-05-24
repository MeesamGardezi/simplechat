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
  const database = db;

  database.exec(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      username TEXT UNIQUE NOT NULL,
      email TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      avatar_color TEXT NOT NULL DEFAULT '#075E54',
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS rooms (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      is_group INTEGER NOT NULL DEFAULT 0,
      created_by TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      FOREIGN KEY (created_by) REFERENCES users(id)
    );

    CREATE TABLE IF NOT EXISTS room_members (
      room_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      joined_at TEXT NOT NULL DEFAULT (datetime('now')),
      PRIMARY KEY (room_id, user_id),
      FOREIGN KEY (room_id) REFERENCES rooms(id),
      FOREIGN KEY (user_id) REFERENCES users(id)
    );

    CREATE TABLE IF NOT EXISTS messages (
      id TEXT PRIMARY KEY,
      room_id TEXT NOT NULL,
      sender_id TEXT NOT NULL,
      content TEXT NOT NULL,
      reply_to_id TEXT,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now')),
      FOREIGN KEY (room_id) REFERENCES rooms(id),
      FOREIGN KEY (sender_id) REFERENCES users(id),
      FOREIGN KEY (reply_to_id) REFERENCES messages(id)
    );

    CREATE TABLE IF NOT EXISTS reactions (
      id TEXT PRIMARY KEY,
      message_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      emoji TEXT NOT NULL,
      UNIQUE(message_id, user_id, emoji),
      FOREIGN KEY (message_id) REFERENCES messages(id),
      FOREIGN KEY (user_id) REFERENCES users(id)
    );
  `);

  // Seed a general room
  const generalExists = database.prepare("SELECT id FROM rooms WHERE name = 'General'").get();
  if (!generalExists) {
    const systemUserId = uuidv4();
    const generalRoomId = uuidv4();

    database.prepare(`
      INSERT OR IGNORE INTO users (id, username, email, password_hash, avatar_color)
      VALUES (?, 'system', 'system@simplechat.app', 'disabled', '#075E54')
    `).run(systemUserId);

    database.prepare(`
      INSERT INTO rooms (id, name, is_group, created_by)
      VALUES (?, 'General', 1, ?)
    `).run(generalRoomId, systemUserId);
  }
}

export function getReactionsForMessages(messageIds: string[]): Map<string, { emoji: string; count: number; users: string[] }[]> {
  const database = getDb();
  const map = new Map<string, { emoji: string; count: number; users: string[] }[]>();

  if (messageIds.length === 0) return map;

  const placeholders = messageIds.map(() => '?').join(',');
  const rows = database.prepare(`
    SELECT r.message_id, r.emoji, u.username
    FROM reactions r
    JOIN users u ON r.user_id = u.id
    WHERE r.message_id IN (${placeholders})
    ORDER BY r.message_id, r.emoji
  `).all(...messageIds) as { message_id: string; emoji: string; username: string }[];

  for (const row of rows) {
    if (!map.has(row.message_id)) map.set(row.message_id, []);
    const msgReactions = map.get(row.message_id)!;
    const existing = msgReactions.find(r => r.emoji === row.emoji);
    if (existing) {
      existing.count++;
      existing.users.push(row.username);
    } else {
      msgReactions.push({ emoji: row.emoji, count: 1, users: [row.username] });
    }
  }

  return map;
}
