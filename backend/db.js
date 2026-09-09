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
  fs.writeFileSync(DB_PATH, Buffer.from(data));
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

    CREATE INDEX IF NOT EXISTS idx_media_group_date ON media(group_id, taken_at);
    CREATE INDEX IF NOT EXISTS idx_media_uploader ON media(group_id, uploader_id);
  `).run();

  process.on('exit', saveNow);
  process.on('SIGINT', () => { saveNow(); process.exit(); });
  process.on('SIGTERM', () => { saveNow(); process.exit(); });
}

module.exports = { initDB, prepare };
