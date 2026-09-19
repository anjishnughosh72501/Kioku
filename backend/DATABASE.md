# Kioku Backend — Datastore Architecture & Scaling Guide

**Datastore Engine:** SQLite (via native `better-sqlite3`) with Write-Ahead Logging (WAL) Mode  
**Target Deployment:** Self-hosted close-friend group (1–50 active users)

---

## 1. Architectural Overview

The Kioku backend utilizes a native SQLite database (`better-sqlite3`) configured with Write-Ahead Logging (`WAL`) mode and prepared statement caching. The database schema stores:
- Friend account hashes (`friend_accounts`) for cryptographic JWT authorization
- Pending friend requests & mutual pairings (`friend_requests`)
- Short-lived E2EE album invitations & sealed key claims (`album_invites`, `claim_tokens`)
- Legacy metadata records (`groups`, `users`, `media`, `flashbacks`) if legacy demo mode is enabled

### Zero-Knowledge Data Separation
Crucially, **no plaintext photos, media buffers, album keys, or personal media metadata reside in this database**. The database serves purely as an encrypted metadata relay and authentication cache.

---

## 2. Durability & Crash Safety

### Native WAL & Atomic File Handling
To provide high performance and crash resilience:
1. `better-sqlite3` runs in Write-Ahead Logging (`WAL`) mode (`db.pragma('journal_mode = WAL')`), allowing concurrent readers without blocking writes.
2. Synchronous mode is tuned to `NORMAL`, providing complete durability across power interruptions without disk sync bottlenecks.
3. Statement caching ensures parameterized queries are compiled once and reused across requests.

### Process Termination Trapping
Process signal listeners (`SIGINT`, `SIGTERM`, `exit`) hook into the database lifecycle to ensure any pending transactions are cleanly finalized and the SQLite handle closes safely.

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

Because `better-sqlite3` operates directly on disk pages with WAL mode, single-node VPS deployments easily support hundreds of concurrent groups and requests.

---

## 4. Production Edge & Migration Paths

### Cloudflare Workers + D1 (Production Live Backend)
The primary production backend for Kioku is deployed globally serverless at `backend-worker/kioku-api` using Cloudflare Workers and Cloudflare D1 distributed SQLite, providing zero-cold-start edge execution.

### PostgreSQL (For Distributed Multi-Node Kubernetes)
For organizations deploying the Node.js backend to multi-node clusters:
- **Advantages**: Multi-instance concurrency, connection pooling (PgBouncer), native JSONB, cross-node replication.
- **Pairing with Redis**: Combine with Redis signaling pub/sub (`SIGNALING.md`) for horizontal scalability across multiple containers.
