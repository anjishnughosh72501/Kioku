# Kioku Backend — Datastore Architecture & Scaling Guide

**Datastore Engine:** SQLite (via WebAssembly sql.js) with Atomic Write Persistence  
**Target Deployment:** Self-hosted close-friend group (1–50 active users)

---

## 1. Architectural Overview

The Kioku backend utilizes an in-process SQLite instance (sql.js) backed by an atomic file-flushing engine. The database schema stores:
- Friend account hashes (riend_accounts) for cryptographic JWT authorization
- Pending friend requests & mutual pairings (riend_requests)
- Short-lived E2EE album invitations & sealed key claims (lbum_invites, claim_tokens)
- Legacy metadata records (groups, users, media, lashbacks) if legacy demo mode is enabled

### Zero-Knowledge Data Separation
Crucially, **no plaintext photos, media buffers, album keys, or personal media metadata reside in this database**. The database serves purely as an encrypted metadata relay and authentication cache.

---

## 2. Durability & Crash Safety (P1-5)

### Atomic File Writes
To prevent database corruption during sudden OS crashes or power interruptions:
1. When a mutating SQL query executes, writes are debounced (scheduleSave) over a 500ms window.
2. The in-memory SQLite buffer is exported and written to a temporary sibling file: etro.db.tmp.
3. An atomic filesystem rename (s.renameSync) replaces etro.db, ensuring that partially-written files never replace valid state.

### Process Termination Trapping
Process signal listeners (SIGINT, SIGTERM, exit) hook into the database lifecycle:
- Any unwritten debounced buffer is immediately committed via saveNow().

### Transactional Wrapper
Multi-step state changes (such as invite claim token generation and redemption) can be wrapped using:
`javascript
const { transaction } = require('./db');

transaction(() => {
  prepare('UPDATE album_invites SET status = ? WHERE id = ?').run('accepted', inviteId);
  prepare('DELETE FROM claim_tokens WHERE token = ?').run(token);
});
`
BEGIN TRANSACTION, COMMIT, and ROLLBACK are executed atomically with error bubbling.

---

## 3. Scaling Envelope & Operational Boundaries

| Metric | Safe Operational Envelope | Scaling Ceiling |
| :--- | :--- | :--- |
| **Active Friend Groups** | 1 – 20 groups | ~100 groups |
| **Concurrent WebSockets** | 1 – 200 connections | ~1,000 connections |
| **Database File Size** | < 50 MB | ~200 MB |
| **Write Frequency** | Up to 10 writes/sec | ~50 writes/sec |

Because sql.js serializes the database into a Node.js Buffer during disk flushes, single deployments running thousands of concurrent groups should transition to a dedicated file-backed or client-server database.

---

## 4. Migration Paths

### Option A: etter-sqlite3 (Recommended for Large Single-Node VPS)
- **Advantages**: Native C++ SQLite with Write-Ahead Logging (WAL) mode. Zero memory-to-disk export overhead; reads/writes happen directly on disk pages with full ACID concurrency.
- **Migration steps**:
  1. Replace const SQL = await initSqlJs() in ackend/db.js with 
ew Database('retro.db').
  2. Enable WAL mode: db.pragma('journal_mode = WAL');.
  3. Update package.json dependencies.

### Option B: PostgreSQL (Recommended for Distributed / Multi-Node Kubernetes)
- **Advantages**: Multi-instance concurrency, connection pooling (PgBouncer), native JSONB, cross-node replication.
- **Pairing with P2-12**: Combine with Redis signaling pub/sub (SIGNALING.md) for horizontal scalability across multiple containers.
