export interface Env {
  DB: D1Database;
  JWT_SECRET?: string;
  CORS_ORIGINS?: string;
}

export interface FriendAuthPayload {
  friendCode: string;
  iat?: number;
  exp?: number;
}

export interface LegacyAuthPayload {
  userId: string;
  groupId: string;
  name: string;
  iat?: number;
  exp?: number;
}

export interface FriendAccountRow {
  friend_code: string;
  secret_hash: string;
  username: string | null;
  created_at: number;
}

export interface FriendRequestRow {
  id: string;
  from_code: string;
  to_code: string;
  from_name: string | null;
  status: string;
  created_at: number;
  updated_at: number;
}

export interface FriendRow {
  user_a: string;
  user_b: string;
  created_at: number;
}

export interface InviteRow {
  id: string;
  invite_code: string;
  created_by: string;
  from_name: string | null;
  expires_at: number;
  status: string;
  created_at: number;
}

export interface AlbumInviteRow {
  id: string;
  album_id: string;
  album_name: string;
  from_code: string;
  to_code: string;
  from_name: string | null;
  claim_token: string | null;
  inviter_pub_key: string | null;
  status: string;
  created_at: number;
  updated_at: number;
}

export interface ClaimTokenRow {
  token: string;
  album_id: string;
  inviter_pub_key: string;
  recipient_pub_key: string | null;
  sealed_key: string | null;
  expires_at: number;
  used: number;
  created_at: string;
}

export interface GroupRow {
  id: string;
  name: string;
  invite_code: string;
  drive_folder_id: string | null;
  created_at: string;
}

export interface UserRow {
  id: string;
  name: string;
  group_id: string;
  created_at: string;
}

export interface MediaRow {
  id: string;
  drive_file_id: string;
  group_id: string;
  uploader_id: string;
  type: 'photo' | 'video';
  caption: string | null;
  taken_at: string | null;
  uploaded_at: string;
  uploader_name?: string;
}

export interface FlashbackRow {
  id: string;
  group_id: string;
  period: 'daily' | 'weekly' | 'monthly' | 'yearly';
  generated_for: string;
  media_ids: string;
  created_at: string;
}

export type HonoVariables = {
  friendCode?: string;
  legacyUser?: LegacyAuthPayload;
};

export type AppEnv = {
  Bindings: Env;
  Variables: HonoVariables;
};
