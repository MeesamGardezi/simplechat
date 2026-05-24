# SimpleChat

A clean, WhatsApp-style chat app — messaging, reactions, and replies.

**Backend:** Node.js + TypeScript + Socket.io + SQLite  
**Frontend:** Flutter

---

## Quick Start

### Backend

```bash
cd backend
cp .env.example .env        # edit JWT_SECRET
npm install
npm run dev                 # runs on http://localhost:3000
```

### Flutter App

```bash
cd frontend
flutter pub get
flutter run                 # Android/iOS/Web/Desktop
```

> Change `kBaseUrl` in `lib/main.dart` to your backend IP when running on a real device.
> Example: `const String kBaseUrl = 'http://192.168.1.10:3000';`

---

## Features

- **Register / Login** — JWT auth, persisted across app restarts
- **Rooms list** — DMs and group chats, sorted by latest message
- **Real-time messaging** — Socket.io, instant delivery
- **Reactions** — Long-press any message → pick from 8 quick emojis; tap a reaction to toggle
- **Replies** — Long-press → Reply; quoted preview shown inside bubble
- **Typing indicators** — Live "X is typing…" in the chat header
- **Infinite scroll** — Scroll up to load older messages
- **Group chats** — Create groups with multiple users
- **General room** — Every user auto-joins on registration

---

## API

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/auth/register` | Register |
| POST | `/api/auth/login` | Login |
| GET | `/api/rooms` | List user rooms |
| POST | `/api/rooms` | Create group |
| POST | `/api/rooms/dm` | Create/get DM |
| GET | `/api/rooms/users/all` | List all users |
| GET | `/api/messages/:roomId` | Get messages (paginated) |

## Socket Events

| Event (client → server) | Payload |
|--------------------------|---------|
| `send_message` | `{ room_id, content, reply_to_id? }` |
| `add_reaction` | `{ message_id, emoji }` |
| `remove_reaction` | `{ message_id, emoji }` |
| `typing` | `{ room_id, is_typing }` |

| Event (server → client) | Payload |
|--------------------------|---------|
| `new_message` | Full message object |
| `reaction_updated` | `{ message_id, reactions[] }` |
| `user_typing` | `{ user_id, username, room_id, is_typing }` |
