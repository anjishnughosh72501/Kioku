-- Migration 0003: Idempotent user bootstrap schema support
-- Ensures users table has friend_code, username, and avatar columns
CREATE TABLE IF NOT EXISTS users (
  id          TEXT PRIMARY KEY,
  username    TEXT,
  friend_code TEXT UNIQUE,
  avatar      TEXT,
  created_at  INTEGER
);

CREATE INDEX IF NOT EXISTS idx_users_friend_code ON users(friend_code);
