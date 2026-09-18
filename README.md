<div align="center">

<img src="assets/kiokulogo.jpg" width="170" alt="Kioku Logo" style="border-radius: 36px; box-shadow: 0 10px 30px rgba(0,0,0,0.15);"/>

# Kioku · 記憶

### *Your private scrapbook for the people who matter most.*

*A warm, zero-knowledge, local-first memory album for the people you love.*

<br>

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![E2EE](https://img.shields.io/badge/Security-libsodium_E2EE-2e7d32?style=for-the-badge&logo=shield)](https://libsodium.gitbook.io/)
[![Cloudflare](https://img.shields.io/badge/Cloudflare-Workers_%2B_D1-F38020?style=for-the-badge&logo=cloudflare&logoColor=white)](https://workers.cloudflare.com/)
[![Node.js](https://img.shields.io/badge/Node.js-18+-339933?style=for-the-badge&logo=node.js&logoColor=white)](https://nodejs.org)
[![Riverpod](https://img.shields.io/badge/Riverpod-2.6-7F52FF?style=for-the-badge)](https://riverpod.dev)
[![License](https://img.shields.io/badge/License-MIT-amber?style=for-the-badge)](LICENSE)
[![Download APK](https://img.shields.io/badge/Download-APK_V1.0-E06D53?style=for-the-badge&logo=android&logoColor=white)](releases/V1-Release.apk)

<p align="center">
  <a href="releases/V1-Release.apk"><b>👉 Download Android APK (Release V1.0)</b></a> · 
  <a href="releases/README.md">Release Notes & Checksums</a>
</p>

</div>

---

# ✨ Why Kioku?

Most apps are built for sharing with the world.

Social feeds encourage performance, metrics, and algorithms. But real life happens in small circles: a quiet coffee with a partner, inside jokes with best friends, or holiday dinners with family.

**Kioku** is built from the ground up around an uncompromising **zero-knowledge, end-to-end encrypted (E2EE), local-first architecture**:

- **Zero-Knowledge Privacy**: All photos, videos, and metadata are encrypted client-side using **libsodium** before ever leaving your device. No server, cloud provider, or observer can ever peek into your memories. Plaintext media never touches any remote backend.
- **User-Owned Storage (BYOS)**: Store your encrypted envelopes where you choose—your personal **Google Drive**, **S3-compatible bucket** (AWS S3, Cloudflare R2, MinIO), **WebDAV server** (Nextcloud, Synology), **local on-device storage**, or via **P2P Mesh WebRTC**.
- **Tactile Japanese Stationery**: Warm cream papers, washi tapes, hanko stamps, and soft claymorphic interactions that feel like opening a physical scrapbook.

---

# 🌿 Key Features & Technical Highlights

### 🌸 Japanese Stationery Aesthetic
- **Washi Tape & Hanko Stamps**: Organic visual accents with Japanese motifs, authentic ink textures, and screen-reader accessibility.
- **Claymorphic UI**: Soft, tactile cards with gentle debossed and elevated clay shadows.
- **Curated High-Contrast Themes**:
  - ☕ **Coffee Light**: Warm parchment paper, rich espresso typography, toasted latte tones.
  - 🌲 **Forest Dark**: Deep roasted bean canvas (`#0F0B08`), high-contrast oat grey text (`#B09E92`, WCAG AA compliant), and warm golden caramel accents (`#E5AF72`).

### 🛡️ End-to-End Encryption & Deterministic BIP-39 Recovery
- **libsodium Cryptographic Engine**: Industrial-grade `XChaCha20-Poly1305` chunked streaming encryption for media and `crypto_secretbox` for metadata envelopes.
- **Three-Tier Key Hierarchy**:
  - **Master Key**: Generated on-device and held securely in hardware-backed storage (`flutter_secure_storage` with Android EncryptedSharedPreferences and iOS Keychain FirstUnlock).
  - **Album Encryption Keys (AEK)**: Unique per-album keys wrapped using recipient public keys (`crypto_box_seal`).
  - **File Keys**: Ephemeral 256-bit keys minted per photo/video and sealed inside the encrypted metadata header.
- **Deterministic 24-Word BIP-39 Recovery**:
  - Generate a standard 24-word recovery phrase upon vault creation.
  - Dedicated **Recovery Key Screen** with 24-word grid, full phrase paste, validation, and visual unlock animations.
  - **Guarded Master Key Initialization**: Prevents silent overwrite and data loss by requiring explicit recovery if an existing encrypted vault is detected on disk.
  - **Mutual Recovery Blob**: Authenticated verification ensuring that only the correct phrase can decrypt the local vault.

### 🌐 Edge-Native Backend (Cloudflare Workers + D1) & SQLite WAL
- **Cloudflare Workers + D1**: Globally distributed serverless API handling user identity, friendships, album memberships, invite routing, and WebRTC signal exchanges with zero cold starts.
- **Native WAL Node.js Persistence**: Companion backend powered by `better-sqlite3` in Write-Ahead Logging (`WAL`) mode with prepared statement caching and graceful process exit hooks (`SIGINT`, `SIGTERM`).
- **Redis Pub/Sub Signaling Cluster**: Scalable multi-instance WebRTC signaling powered by `ioredis` with automatic fallback to memory signaling.

### 👥 Dedicated 4-Tab Social Hub & Synchronized State
- **4-Tab Navigation**:
  - **Friends**: View active friends, manage shared albums, and remove connections.
  - **Incoming**: Pending friend requests with inviter names, timestamps, and 1-tap **Accept** or **Decline**.
  - **Sent**: Track outgoing invitations with live status badges (`Pending` vs `Expired`) and 1-tap **Cancel** or **Resend**.
  - **Add Friend**: Enter 6-character friend codes or paste short invite links.
- **Server Authority with Local Cache**: Background friend reconciliation on startup (`reconcileFriends`) ensuring fast offline launches without stale data.
- **Optimistic UI Updates**: Instant interface transitions on social actions with automatic rollback on network failure.

### 🔗 Universal Short Invite Links (`kioku.app/i/:code`)
- **6-Character Cryptographic Invite Codes**: Unambiguous codes with a 30-day TTL.
- **Deep Linking Integration**: Configured for Android App Links and iOS Universal Links (`https://kioku.app/i/*`, `https://kioku.app/invite/*`, and `kioku://i/*`).
- **Cold-Start Resume**: Unauthenticated or locked app launches cache the incoming invite and automatically resume the join flow upon sign-in/unlock.

### 🗂️ Canonical Album Sharing & Automated Key Rotation
- **Zero-Knowledge Key Exchange**: Album Encryption Keys (AEK) are exchanged securely via asymmetric `crypto_box_seal` using device public keys.
- **Forward-Secrecy Key Rotation**: When an album member is removed, Kioku automatically rotates the AEK and distributes the new wrapped key to remaining members.
- **Standardized 5-Step Media Deletion Pipeline**:
  1. Look up target media envelope in repository.
  2. Delete remote storage blob from provider (Drive, S3, WebDAV, local).
  3. Eradicate metadata from persistent index.
  4. Securely overwrite and delete temporary local disk files.
  5. Evict from memory and dual-tier LRU caches.

### ⚡ Performance & Memory Safeguards
- **Feed Pagination Controller**: Page-by-page loading (20 items per page) with 80% / 400px prefetch threshold.
- **Parallel Flashback Thumbnails**: Concurrently loads thumbnail previews (concurrency cap 4) without downloading full-resolution originals.
- **Dual-Tier Byte-Budget LRU Caches**: Strict limits of 50 MB for media and 20 MB for thumbnails to eliminate out-of-memory crashes on resource-constrained devices.
- **Centralized HTTP Client**: `HttpClientHelper` with request timeouts (5s API, 30s upload), exponential retry backoff, and typed exception handling.

---

# 🏗️ Architecture Overview

```mermaid
graph TD
    subgraph Client [Flutter Mobile App (Client-Side E2EE)]
        UI[UI: Feed, Albums, Flashbacks, Social Hub]
        Repo[EncryptedMemoryRepository]
        Crypto[CryptoCore & libsodium]
        KeyStore[KeyStore & BIP39 Recovery]
        LRU[Dual ByteBudgetLruCache]
        Net[HttpClientHelper & Error Taxonomy]
    end

    subgraph Storage [Polymorphic Storage Layer]
        Drive[Google Drive Provider]
        S3[S3-Compatible Provider]
        WebDAV[WebDAV Provider]
        Local[Local Storage Provider]
        Mesh[P2P Mesh WebRTC Provider]
    end

    subgraph Edge [Edge & Cloud Infrastructure]
        Worker[Cloudflare Worker API]
        D1[(Cloudflare D1 Database)]
        Redis[(Redis Pub/Sub Signaling)]
        NodeBackend[Node.js WAL SQLite Backend]
    end

    UI --> Repo
    Repo --> Crypto
    Repo --> KeyStore
    Repo --> LRU
    Repo --> Net
    Repo --> Storage

    Net --> Worker
    Worker --> D1
    Net --> NodeBackend
    NodeBackend --> Redis
```

---

# 📂 Project Structure

```text
Kioku
│
├── flutter_mobile/                  # Flutter mobile client (Android & iOS)
│   ├── android/
│   │   ├── app/
│   │   │   ├── build.gradle.kts     # Kotlin DSL with release signing & R8 rules
│   │   │   ├── proguard-rules.pro   # Proguard keep rules for libsodium & SQLCipher
│   │   │   └── src/main/AndroidManifest.xml # Deep linking intent filters
│   │   └── key.properties.example   # Template for release signing keystore
│   ├── ios/
│   │   └── Runner/Runner.entitlements # Associated Domains for Universal Links
│   ├── lib/
│   │   ├── core/                    # Crypto, storage, networking, LRU caching
│   │   │   ├── crypto/              # KeyStore, BIP-39 recovery, libsodium
│   │   │   ├── network/             # HttpClientHelper with retry backoff
│   │   │   └── storage/             # Polymorphic storage engines (Drive, S3, WebDAV)
│   │   ├── features/
│   │   │   ├── auth/                # Sign-in, onboarding, RecoveryKeyScreen
│   │   │   ├── feed/                # Infinite scroll feed & encrypted repository
│   │   │   ├── flashbacks/          # Flashback memory controller & views
│   │   │   ├── friends/             # 4-tab Social Hub & friend controller
│   │   │   ├── albums/              # Dedicated album hub & 2x2 grid
│   │   │   └── media_viewer/        # Zero-leak video player & photo viewer
│   │   ├── app_router.dart          # GoRouter navigation & deep link listener
│   │   └── main.dart                # App bootstrap & key store initialization
│   └── test/                        # 98 unit and widget tests
│
├── backend-worker/                  # Cloudflare Workers + D1 Edge API
│   └── kioku-api/
│       ├── src/                     # Worker endpoints & D1 database queries
│       ├── test/                    # 47 automated Worker tests
│       └── wrangler.toml            # Cloudflare Worker deployment configuration
│
├── backend/                         # Node.js + Express + better-sqlite3 reference backend
│   ├── routes/                      # API routes (auth, friends, invites, albums)
│   ├── services/                    # Redis Pub/Sub signaling & storage services
│   ├── __tests__/                   # 67 Jest test suites
│   ├── db.js                        # better-sqlite3 WAL database wrapper
│   └── server.js                    # Express application & WebSocket signaling
│
├── releases/                        # Standalone release APKs & SHA-256 checksums
│   ├── V1-Release.apk               # Official production release build
│   └── README.md                    # Release notes and verification hashes
├── assets/                          # App logos and visual branding
└── LICENSE                          # MIT License
```

---

# 🚀 Getting Started

## Prerequisites

- **Flutter SDK**: 3.22+ (Dart 3.x)
- **Node.js**: 18+ (for local backend and test runners)
- **Android Studio / SDK**: Android SDK 34+ and Android device or emulator

---

## 1. Running the Flutter App

```bash
cd flutter_mobile

# Install Flutter dependencies
flutter pub get

# Run test suite (98 tests)
flutter test

# Run the app in debug mode
flutter run
```

### Building the Production Release APK

```bash
cd flutter_mobile
flutter build apk --release
```

The compiled APK will be generated at:
```text
flutter_mobile/build/app/outputs/flutter-apk/app-release.apk
```

---

## 2. Cloudflare Worker Edge Backend

The primary backend is serverless and runs on Cloudflare Workers with D1:

```bash
cd backend-worker/kioku-api

# Install dependencies
npm install

# Run automated tests (47 tests)
npm test

# Run locally via Wrangler
npx wrangler dev
```

To deploy to Cloudflare:
```bash
npx wrangler d1 create kioku-d1
npx wrangler deploy
```

---

## 3. Local Node.js Backend (Optional Reference)

```bash
cd backend

# Install dependencies
npm install

# Run Jest tests (67 tests)
npm test

# Start local server
npm start
```

Runs by default at `http://localhost:4000`.

---

# 🧪 Verification & Test Coverage

All modules in Kioku are thoroughly tested across all layers:

| Layer | Framework | Tests | Status |
| :--- | :--- | :--- | :--- |
| **Flutter Mobile** | Flutter Test / Mockito | **98 unit & widget tests** | ✅ Passing |
| **Cloudflare Worker** | Miniflare / Vitest | **47 automated tests** | ✅ Passing |
| **Node.js Backend** | Jest / Supertest | **67 unit & integration tests** | ✅ Passing |
| **Dart Analyzer** | `flutter analyze` | **0 issues found** | ✅ Clean |

To run the complete mobile test suite:
```bash
cd flutter_mobile
flutter test
flutter analyze --no-fatal-infos
```

---

# 🌸 Philosophy

> **The best memories aren't the loudest ones.**

Kioku was created around a simple idea:

Digital memories should feel as comforting as opening an old scrapbook—filled with paper, ink, photographs, and the people who make those moments meaningful.

No feeds. No followers. No data mining. Just memories.

---

<div align="center">

### Made with ❤️ for meaningful moments

**Kioku · 記憶**

</div>
