export interface Env {
  DB: D1Database;
  JWT_SECRET?: string;
  CORS_ORIGINS?: string;
  ENVIRONMENT?: string;
}

export interface FriendAuthPayload {
  friendCode: string;
  userId?: string;
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

export interface AlbumRow {
  id: string;
  owner_user_id: string;
  title: string;
  storage_type: string;
  storage_reference: string | null;
  current_epoch: number;
  created_at: number;
  updated_at: number;
}

export interface AlbumMemberRow {
  album_id: string;
  user_id: string;
  role: 'owner' | 'member';
  status: 'active' | 'pending' | 'revoked';
  joined_at: number;
  updated_at: number;
  displayName?: string | null;
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
  inviter_identity: string | null;
  recipient_identity: string | null;
  recipient_pub_key: string | null;
  sealed_key: string | null;
  claim_status: 'created' | 'redeemed' | 'sealed' | 'consumed' | 'expired';
  expires_at: number;
  used: number;
  created_at: number | string;
  updated_at?: number | null;
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
  userId?: string;
  legacyUser?: LegacyAuthPayload;
};

export type AppEnv = {
  Bindings: Env;
  Variables: HonoVariables;
};
