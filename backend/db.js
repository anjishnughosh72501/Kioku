const initSqlJs = require('sql.js');
const fs = require('fs');
const path = require('path');

const DB_PATH = path.join(__dirname, 'retro.db');

let _db = null;
let _dirty = false;
let _saveTimer = null;

function scheduleSave() {
  if (_dirty) return;
  _dirty = true;
  _saveTimer = setTimeout(() => {
    _dirty = false;
    if (!_db) return;
    const data = _db.export();
    fs.writeFileSync(DB_PATH, Buffer.from(data));
  }, 500);
}

function saveNow() {
  if (_saveTimer) { clearTimeout(_saveTimer); _saveTimer = null; }
  _dirty = false;
  if (!_db) return;
  const data = _db.export();
  const tmpPath = `${DB_PATH}.tmp`;
  try {
    fs.writeFileSync(tmpPath, Buffer.from(data));
    try {
      fs.renameSync(tmpPath, DB_PATH);
    } catch (renameErr) {
      fs.copyFileSync(tmpPath, DB_PATH);
      try { fs.unlinkSync(tmpPath); } catch (_) {}
    }
  } catch (err) {
    fs.writeFileSync(DB_PATH, Buffer.from(data));
  }
}

function transaction(fn) {
  if (!_db) throw new Error('Database not initialized');
  _db.exec('BEGIN TRANSACTION');
  try {
    const result = fn();
    _db.exec('COMMIT');
    scheduleSave();
    return result;
  } catch (error) {
    _db.exec('ROLLBACK');
    throw error;
  }
}

function prepare(sql) {
  return {
    all(...params) {
      const stmt = _db.prepare(sql);
      if (params.length) stmt.bind(params);
      const rows = [];
      while (stmt.step()) rows.push(stmt.getAsObject());
      stmt.free();
      return rows;
    },
    get(...params) {
      const stmt = _db.prepare(sql);
      if (params.length) stmt.bind(params);
      let row = null;
      if (stmt.step()) row = stmt.getAsObject();
      stmt.free();
      return row || undefined;
    },
    run(...params) {
      if (params.length) _db.run(sql, params);
      else _db.exec(sql);
      scheduleSave();
      return { changes: _db.getRowsModified() };
    },
  };
}

async function initDB() {
  const SQL = await initSqlJs();
  if (fs.existsSync(DB_PATH)) {
    const buffer = fs.readFileSync(DB_PATH);
    _db = new SQL.Database(buffer);
  } else {
    _db = new SQL.Database();
  }

  prepare(`
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
  `).run();

  // Non-destructive schema migration for existing databases
  try {
    _db.exec(`ALTER TABLE friend_accounts ADD COLUMN username TEXT;`);
  } catch (_) {
    // Column already exists
  }

  process.on('exit', saveNow);
  process.on('SIGINT', () => { saveNow(); process.exit(); });
  process.on('SIGTERM', () => { saveNow(); process.exit(); });
}

module.exports = { initDB, prepare, transaction, saveNow };
