export interface User {
  id: string;
  username: string;
  email: string;
  password_hash: string;
  avatar_color: string;
  last_seen: string | null;
  created_at: string;
}

export interface Room {
  id: string;
  name: string;
  is_group: number;
  created_by: string;
  created_at: string;
}

export interface RoomMember {
  room_id: string;
  user_id: string;
  joined_at: string;
}

export interface Message {
  id: string;
  room_id: string;
  sender_id: string;
  content: string;
  reply_to_id: string | null;
  client_id: string | null;
  created_at: string;
  updated_at: string;
}

export interface Reaction {
  id: string;
  message_id: string;
  user_id: string;
  emoji: string;
}

export interface ReactionCount {
  emoji: string;
  count: number;
  users: string[];
}

export interface MessageWithMeta extends Omit<Message, 'sender_id'> {
  sender_id: string;
  sender_username: string;
  sender_color: string;
  reactions: ReactionCount[];
  reply_to: ReplyPreview | null;
  status: 'sent' | 'delivered' | 'read';
}

export interface ReplyPreview {
  id: string;
  sender_username: string;
  content: string;
}

export interface JwtPayload {
  userId: string;
  username: string;
}
