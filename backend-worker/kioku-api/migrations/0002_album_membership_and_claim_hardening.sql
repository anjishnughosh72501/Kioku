-- 0002_album_membership_and_claim_hardening.sql
-- Server-authoritative albums, membership, and hardened claim exchange

-- ALBUMS
CREATE TABLE IF NOT EXISTS albums (
  id                TEXT PRIMARY KEY,
  owner_user_id     TEXT NOT NULL,
  title             TEXT NOT NULL,
  storage_type      TEXT DEFAULT 'local',
  storage_reference TEXT,
  current_epoch     INTEGER DEFAULT 1,
  created_at        INTEGER NOT NULL,
  updated_at        INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_albums_owner ON albums(owner_user_id);

-- ALBUM MEMBERS (Canonical Server-Side Membership)
CREATE TABLE IF NOT EXISTS album_members (
  album_id          TEXT NOT NULL,
  user_id           TEXT NOT NULL,
  role              TEXT NOT NULL CHECK(role IN ('owner', 'member')),
  status            TEXT NOT NULL DEFAULT 'active' CHECK(status IN ('active', 'pending', 'revoked')),
  joined_at         INTEGER NOT NULL,
  updated_at        INTEGER NOT NULL,
  PRIMARY KEY (album_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_album_members_user ON album_members(user_id, status);
CREATE INDEX IF NOT EXISTS idx_album_members_album ON album_members(album_id, status);

-- ALTER claim_tokens for hardened lifecycle binding
ALTER TABLE claim_tokens ADD COLUMN inviter_identity TEXT;
ALTER TABLE claim_tokens ADD COLUMN recipient_identity TEXT;
ALTER TABLE claim_tokens ADD COLUMN claim_status TEXT DEFAULT 'created';
ALTER TABLE claim_tokens ADD COLUMN updated_at INTEGER;
