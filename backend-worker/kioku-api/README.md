# Kioku API — Cloudflare Workers + D1 Backend

Production edge API for Kioku, migrated from Express + SQLite to **Cloudflare Workers** and **Cloudflare D1**.

Preserves **100% of Flutter API contracts, route names, database schemas, cryptographic signatures, friend request state machines, album invitations, short universal invite links, zero-knowledge claim exchanges, and WebRTC mesh signaling**.

---

## 🚀 Key Highlights & Architectural Parity

- **Runtime:** Cloudflare Workers (V8 edge isolates, sub-millisecond cold starts, global replication)
- **Database:** Cloudflare D1 with prepared statements (`env.DB.prepare().bind()`)
- **Web Framework:** [Hono](https://hono.dev/) for type-safe routing and middleware
- **Zero-Knowledge Cryptography:** Native Web Crypto API (`crypto.subtle`) for:
  - SHA-256 device secret hashing (`hashSecret`)
  - HMAC-SHA256 JWT tokens (90-day expiry for device auth, byte-for-byte compatible with Node's `jsonwebtoken`)
  - Cryptographically secure invite and ID generation
- **WebRTC Signaling:** WebSocket relay on `/signal` for peer-to-peer encrypted mesh photo replication
- **Scheduled Flashbacks:** Native Workers Cron Trigger (`0 6 * * *`)

---

## 📋 Endpoints & API Contract

All endpoints match the Express server exactly without requiring any changes to the Flutter app.

| Endpoint | Method | Auth | Description |
| :--- | :--- | :--- | :--- |
| `/health` | `GET` | None | Service health check (`{ ok: true }`) |
| `/privacy` | `GET` | None | Privacy Policy markdown / plain text |
| `/terms` | `GET` | None | Terms of Service |
| `/i/:code` | `GET` | None | Universal invite link landing page (HTML for browser, JSON for app) |
| `/invite/:code` | `GET` | None | Universal invite link landing page (HTML for browser, JSON for app) |
| `/friends/token` | `POST` | Device Secret | Authenticate device and issue signed HS256 JWT |
| `/friends/profile` | `POST` | Bearer Token | Update user display name |
| `/friends/invite` | `POST` | Bearer Token | Create 6-character short universal invite code (30-day TTL) |
| `/friends/invite/:code` | `GET` | None | Publicly resolve invite code details |
| `/friends/request` | `POST` | Bearer Token | Send mutual friend request |
| `/friends/requests/:myCode` | `GET` | Bearer Token | Poll incoming pending requests and accepted requests |
| `/friends/ack` | `POST` | Bearer Token | Acknowledge accepted friend request (mark synced) |
| `/friends/accept` | `POST` | Bearer Token | Accept friend request and insert into normalized `friends` table |
| `/friends/decline` | `POST` | Bearer Token | Decline incoming friend request |
| `/friends/cancel` | `POST` | Bearer Token | Sender cancels pending friend request |
| `/friends/resend` | `POST` | Bearer Token | Sender resends expired/cancelled friend request |
| `/friends/remove` | `POST` | Bearer Token | Remove friendship record |
| `/friends/list/:myCode` | `GET` | Bearer Token | Retrieve accepted mutual friends |
| `/friends/sent/:myCode` | `GET` | Bearer Token | Retrieve sent friend requests with 30-day expiration |
| `/friends/albums/invite` | `POST` | Bearer Token | Send in-app shared album invitation |
| `/friends/albums/invites/:myCode` | `GET` | Bearer Token | Poll incoming album invitations |
| `/friends/albums/accept` | `POST` | Bearer Token | Accept album invitation |
| `/friends/albums/decline` | `POST` | Bearer Token | Decline album invitation |
| `/claim/request` | `POST` | None | Generate short-lived claim token (10-min TTL) for key exchange |
| `/claim/redeem` | `POST` | None | Redeem claim token & register recipient public key |
| `/claim/seal` | `POST` | None | Post sealed collection key (`crypto_box_seal`) |
| `/claim/sealed/:claimToken` | `GET` | None | Poll sealed collection key |
| `/flashbacks` | `GET` | Optional Token | Daily flashback memories for circle |
| `/signal` | `GET` | Token Query | WebRTC signaling WebSocket upgrade for peer mesh replication |

---

## 🛠️ Local Development & Testing

### 1. Install Dependencies
```bash
npm install
```

### 2. Run Automated Test Suite
Vitest runs the full end-to-end test suite against an in-memory Cloudflare D1 mock:
```bash
npm test -- --run
```

### 3. Type Checking
```bash
npm run cf-typegen
npx tsc --noEmit
```

### 4. Start Local Dev Server
```bash
npm run dev
```
The worker will listen on `http://127.0.0.1:8787`.

---

## 🗄️ Database Migrations (Cloudflare D1)

The initial migration is defined in `migrations/0001_initial.sql` (and mirrored in `../schema.sql`).

### Apply to Local D1 Database:
```bash
npx wrangler d1 migrations apply kioku-prod --local
```

### Apply to Remote Production D1 Database:
```bash
npx wrangler d1 migrations apply kioku-prod --remote
```

---

## ☁️ Deployment

### 1. Set Production JWT Secret
```bash
npx wrangler secret put JWT_SECRET
```

### 2. Deploy Worker
```bash
npm run deploy
```

---

## 📱 Connecting Flutter App

To point the Flutter mobile client to your Cloudflare Worker backend, build or run with:
```bash
flutter run --dart-define=BACKEND_URL=https://kioku-api.<your-subdomain>.workers.dev
```
Or for local development:
```bash
# Android emulator loopback to host port 8787
flutter run --dart-define=BACKEND_URL=http://10.0.2.2:8787
```
No Flutter Dart code changes are required!
