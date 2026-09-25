# Kioku Releases

Official standalone release builds for Kioku are distributed via [GitHub Releases](https://github.com/anjishnughosh72501/Kioku/releases) and packaged in the `releases/` directory.

### Current Release: v1.0-Beta (`v1-releaseBeta`)

| File | Platform | Architecture | Size | SHA-256 Checksum | Direct Download |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`v1-releaseBeta.apk`** | Android 5.0+ (API 21+) | Universal (`arm64-v8a`, `armeabi-v7a`, `x86_64`) | 62.0 MB | `90E90112219A8F80F8838E6DD2845C0578BBC9B59586330B51738BFBC8563711` | [Download v1-releaseBeta](v1-releaseBeta.apk) |

---

## 📲 Installation Instructions

### Option 1: Direct Device Install (Android Phone / Tablet)
1. Download [`v1-releaseBeta.apk`](v1-releaseBeta.apk) directly to your Android device.
2. Open the downloaded APK from your browser's download manager or file browser.
3. If prompted by Android, enable **"Install unknown apps"** for your browser or file manager.
4. Tap **Install** and launch Kioku.

### Option 2: Via ADB (Command Line)
Connect your Android device with USB debugging enabled (or start an Android emulator) and run:
```bash
adb install -r releases/v1-releaseBeta.apk
```

---

## 📋 Release Highlights — Kioku V1.0

### 🛡️ 1. Zero-Knowledge E2EE & BIP-39 Deterministic Vault Recovery
- **Deterministic 24-Word Recovery Phrase**: Generate and restore complete cryptographic identity using BIP-39 mnemonic seeds.
- **Dedicated Recovery Key Screen**: 24-word grid with one-tap clipboard paste, phrase validation, and animated recovery state.
- **Guarded Master Key Initialization**: Prevents silent re-keying and data loss by requiring explicit user recovery if an existing encrypted vault is detected.
- **Mutual Recovery Blob**: Authenticated vault verification ensures only the correct master key can unlock your encrypted memories.

### ⚡ 2. High-Reliability Backend & Distributed Architecture
- **Cloudflare Workers + D1 Backend**: Globally distributed, serverless edge API providing zero-cold-start coordination, friendship management, and invite handling.
- **Native WAL SQLite Persistence**: Backend persistence powered by `better-sqlite3` in Write-Ahead Logging (`WAL`) mode with prepared statement caching and graceful process exit hooks.
- **Redis Pub/Sub Signaling Cluster**: Scalable WebRTC signaling across multiple server instances with automatic fallback to local memory store.

### 👥 3. Social Hub & Background Reconciliation
- **4-Tab Social Hub**: Dedicated **Friends**, **Incoming**, **Sent**, and **Add Friend** views with real-time unread badges.
- **Background State Reconciliation**: Server authority with local caching, reconciling friendships seamlessly on app launch.
- **Optimistic UI Updates**: Instant feedback for accepting, declining, canceling, and removing friends with automatic rollback on network failure.

### 🔗 4. Universal Short Invite Links (`kioku.app/i/:code`)
- **6-Character Cryptographic Invite Codes**: Unambiguous codes with 30-day TTL.
- **Android App Links & iOS Universal Links**: Native deep linking via `https://kioku.app/i/*`, `https://kioku.app/invite/*`, and `kioku://i/*`.
- **Pending Link Resolution**: Caches incoming invites during locked or unauthenticated states and resumes join flow seamlessly after authentication.

### 🔐 5. Canonical Album Sharing & Automated Key Rotation
- **Album Encryption Keys (AEK)**: Unique symmetric keys per album wrapped using recipient public keys (`crypto_box_seal`).
- **Automatic Key Rotation**: When a member is removed from an album, the AEK is automatically re-generated and re-encrypted for remaining members.
- **Standardized 5-Step Media Deletion**: Rigorous pipeline guaranteeing remote blob deletion, metadata purge, disk file eradication, and multi-tier LRU cache eviction.

### 🚀 6. Performance & Memory Safeguards
- **Paginated Feed Controller**: Dynamic infinite scroll with 20 items per page and 80% / 400px prefetch threshold.
- **Parallel Flashback Thumbnails**: Batch fetches flashback memories concurrently (max concurrency 4) without downloading full-resolution files.
- **Multi-Tier LRU Caches**: Strict byte-budget cache bounds (50 MB media, 20 MB thumbnails) preventing out-of-memory issues.
- **Resilient HTTP Networking**: Centralized `HttpClientHelper` with exponential backoff (500ms, 1000ms), 5s API timeouts, and 30s upload timeouts.

### 🔒 7. Release Polish & Android Hardening
- **R8 Minification & Resource Shrinking**: Optimized release binary size with full keep rules for Libsodium, SQLCipher, and Flutter Secure Storage.
- **Strict Network Security**: Cleartext traffic strictly disabled for production domains with local test overrides.
