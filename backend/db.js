const Database = require('better-sqlite3');
const fs = require('fs');
const path = require('path');

const DB_PATH = process.env.DB_PATH || path.join(__dirname, 'retro.db');

let _db = null;

function normalizeParams(params) {
  if (params.length === 1 && Array.isArray(params[0])) {
    return params[0];
  }
  return params;
}

function getDb() {
  if (!_db) {
    initDB();
  }
  return _db;
}

function transaction(fn) {
  const db = getDb();
  return db.transaction(fn)();
}

function prepare(sql) {
  const db = getDb();
  const stmt = db.prepare(sql);
  return {
    all(...params) {
      const args = normalizeParams(params);
      return args.length ? stmt.all(...args) : stmt.all();
    },
    get(...params) {
      const args = normalizeParams(params);
      return args.length ? stmt.get(...args) : stmt.get();
    },
    run(...params) {
      const args = normalizeParams(params);
      const res = args.length ? stmt.run(...args) : stmt.run();
      return {
        changes: res.changes,
        lastInsertRowid: res.lastInsertRowid,
      };
    },
  };
}

function saveNow() {
  if (_db) {
    try {
      _db.pragma('wal_checkpoint(PASSIVE)');
    } catch (_) {}
  }
}

function closeDB() {
  if (_db) {
    try {
      saveNow();
      _db.close();
    } catch (_) {}
    _db = null;
  }
}

function initDB() {
  if (_db) return _db;

  _db = new Database(DB_PATH);
  _db.pragma('journal_mode = WAL');
  _db.pragma('foreign_keys = ON');
  _db.pragma('synchronous = NORMAL');

  _db.exec(`
    CREATE TABLE IF NOT EXISTS groups (
      id            TEXT PRIMARY KEY,
      name          TEXT NOT NULL,
      invite_code   TEXT UNIQUE NOT NULL,
      drive_folder_id TEXT,
      created_at    TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS users (
      id          TEXT PRIMARY KEY,
      name        TEXT NOT NULL,
      group_id    TEXT NOT NULL REFERENCES groups(id),
      created_at  TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS media (
      id              TEXT PRIMARY KEY,
      drive_file_id   TEXT NOT NULL,
      group_id        TEXT NOT NULL REFERENCES groups(id),
      uploader_id     TEXT NOT NULL REFERENCES users(id),
      type            TEXT NOT NULL CHECK(type IN ('photo', 'video')),
      caption         TEXT,
      taken_at        TEXT,
      uploaded_at     TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS flashbacks (
      id            TEXT PRIMARY KEY,
      group_id      TEXT NOT NULL REFERENCES groups(id),
      period        TEXT NOT NULL CHECK(period IN ('daily', 'weekly', 'monthly', 'yearly')),
      generated_for TEXT NOT NULL,
      media_ids     TEXT NOT NULL,
      created_at    TEXT DEFAULT (datetime('now')),
      UNIQUE(group_id, period, generated_for)
    );

    CREATE TABLE IF NOT EXISTS claim_tokens (
      token           TEXT PRIMARY KEY,
      album_id        TEXT NOT NULL,
      inviter_pub_key TEXT NOT NULL,
      recipient_pub_key TEXT,
      sealed_key      TEXT,
      expires_at      INTEGER NOT NULL,
      used            INTEGER DEFAULT 0,
      created_at      TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS friend_requests (
      id              TEXT PRIMARY KEY,
      from_code       TEXT NOT NULL,
      to_code         TEXT NOT NULL,
      from_name       TEXT,
      status          TEXT DEFAULT 'pending',
      created_at      INTEGER NOT NULL,
      updated_at      INTEGER NOT NULL
    );

    CREATE TABLE IF NOT EXISTS album_invites (
      id              TEXT PRIMARY KEY,
      album_id        TEXT NOT NULL,
      album_name      TEXT NOT NULL,
      from_code       TEXT NOT NULL,
      to_code         TEXT NOT NULL,
      from_name       TEXT,
      claim_token     TEXT,
      inviter_pub_key TEXT,
      status          TEXT DEFAULT 'pending',
      created_at      INTEGER NOT NULL,
      updated_at      INTEGER NOT NULL
    );

    CREATE TABLE IF NOT EXISTS friend_accounts (
      friend_code     TEXT PRIMARY KEY,
      secret_hash     TEXT NOT NULL,
      username        TEXT,
      created_at      INTEGER NOT NULL
    );

    CREATE TABLE IF NOT EXISTS friends (
      user_a          TEXT NOT NULL,
      user_b          TEXT NOT NULL,
      created_at      INTEGER NOT NULL,
      PRIMARY KEY (user_a, user_b)
    );

    CREATE TABLE IF NOT EXISTS invites (
      id              TEXT PRIMARY KEY,
      invite_code     TEXT UNIQUE NOT NULL,
      created_by      TEXT NOT NULL,
      from_name       TEXT,
      expires_at      INTEGER NOT NULL,
      status          TEXT DEFAULT 'valid',
      created_at      INTEGER NOT NULL
    );

    CREATE INDEX IF NOT EXISTS idx_media_group_date ON media(group_id, taken_at);
    CREATE INDEX IF NOT EXISTS idx_media_uploader ON media(group_id, uploader_id);
    CREATE INDEX IF NOT EXISTS idx_claim_token_exp ON claim_tokens(token, expires_at);
    CREATE INDEX IF NOT EXISTS idx_fr_to_code ON friend_requests(to_code, status);
    CREATE INDEX IF NOT EXISTS idx_fr_from_code ON friend_requests(from_code, status);
    CREATE INDEX IF NOT EXISTS idx_ai_to_code ON album_invites(to_code, status);
    CREATE INDEX IF NOT EXISTS idx_friends_a ON friends(user_a);
    CREATE INDEX IF NOT EXISTS idx_friends_b ON friends(user_b);
    CREATE INDEX IF NOT EXISTS idx_invites_code ON invites(invite_code);
  `);

  // Non-destructive schema migration for existing databases
  try {
    _db.exec(`ALTER TABLE friend_accounts ADD COLUMN username TEXT;`);
  } catch (_) {
    // Column already exists
  }

  process.once('exit', closeDB);
  process.once('SIGINT', () => { closeDB(); process.exit(); });
  process.once('SIGTERM', () => { closeDB(); process.exit(); });

  return _db;
}

module.exports = { initDB, prepare, transaction, saveNow, closeDB, getDb };
