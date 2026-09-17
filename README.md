<div align="center">

<img src="assets/kiokulogo.jpg" width="170" alt="Kioku Logo" style="border-radius: 36px; box-shadow: 0 10px 30px rgba(0,0,0,0.15);"/>

# Kioku · 記憶

### *Your private scrapbook for the people who matter most.*

*A warm, zero-knowledge, local-first memory album for the people you love.*

<br>

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![E2EE](https://img.shields.io/badge/Security-libsodium_E2EE-2e7d32?style=for-the-badge&logo=shield)](https://libsodium.gitbook.io/)
[![Node.js](https://img.shields.io/badge/Node.js-18+-339933?style=for-the-badge&logo=node.js&logoColor=white)](https://nodejs.org)
[![Riverpod](https://img.shields.io/badge/Riverpod-2.6-7F52FF?style=for-the-badge)](https://riverpod.dev)
[![License](https://img.shields.io/badge/License-MIT-amber?style=for-the-badge)](LICENSE)
[![Download APK](https://img.shields.io/badge/Download-APK_V3.2-E06D53?style=for-the-badge&logo=android&logoColor=white)](releases/kioku-v3.2-release.apk)

<p align="center">
  <a href="releases/kioku-v3.2-release.apk"><b>👉 Download Android APK (V3.2)</b></a> · 
  <a href="releases/README.md">Release Notes & Checksums</a>
</p>

</div>

---

# ✨ Why Kioku?

Most apps are built for sharing with everyone.

Social feeds encourage performance, metrics, and algorithms. But real life happens in small circles: a quiet coffee with a partner, inside jokes with best friends, or family dinners.

**Kioku** is built around an uncompromising **zero-knowledge, end-to-end encrypted (E2EE), local-first architecture**:
- **Zero-Knowledge Privacy**: All photos, videos, and metadata are encrypted client-side using **libsodium** before ever leaving your device. No server, cloud provider, or observer can ever peek into your memories.
- **User-Owned Storage Backends**: Store your encrypted envelopes where you choose—your personal **Google Drive**, **S3-compatible bucket** (AWS S3, Cloudflare R2, MinIO), **WebDAV server** (Nextcloud, Synology), **local on-device storage**, or via **P2P Mesh WebRTC**.
- **Tactile Japanese Stationery**: Warm cream papers, washi tapes, hanko stamps, and soft claymorphic interactions.

---

# 🌿 Key Features

### 🌸 Japanese Stationery Aesthetic
- **Washi Tape & Hanko Stamps**: Organic visual accents with Japanese motifs, authentic ink textures, and screen-reader accessibility.
- **Claymorphic UI**: Soft, tactile cards with gentle debossed and elevated clay shadows.
- **Enhanced Curated Themes**:
  - ☕ **Coffee Light**: Warm parchment paper, rich espresso typography, toasted latte tones.
  - 🌲 **Forest Dark**: Deep rich roasted bean canvas (`#0F0B08`), high-contrast oat grey text (`#B09E92`, WCAG AA compliant), and warm golden caramel accents (`#E5AF72`).

### 🗂️ Dedicated Albums Hub & 2×2 Photo Grid
- **Dedicated Albums Tab**: 4-tab bottom navigation (**Feed** | **Albums** | **Flashbacks** | **Profile**) with dedicated album management.
- **2×2 Square Photo Grid**: Clean, edge-to-edge 2×2 photo grid in album details for dense, distraction-free visual browsing.
- **Shareable Deep Links & Invites**: One-tap album invite links generating app-accessible URLs and `kioku://album/<id>` deep links.
- **Home Quick Actions**: Instant access row on the main feed for rapid capture, album browsing, flashbacks, and profile navigation.

### 🛡️ Zero-Knowledge End-to-End Encryption (E2EE)
- **libsodium Cryptographic Engine**: Industrial-grade `XChaCha20-Poly1305` chunked streaming encryption for media and `crypto_secretbox` for metadata.
- **Three-Tier Key Hierarchy**:
  - **Master Key**: Generated on device and held securely in hardware-backed keystores (`flutter_secure_storage`).
  - **Collection Keys**: Unique per-album keys wrapped by the Master Key or device public keys for sharing.
  - **File Keys**: Ephemeral 256-bit keys minted per photo/video and wrapped inside the `.enc` envelope.
- **BIP39 24-Word Recovery Phrase**: Standard mnemonic key recovery with 60s clipboard auto-clear and secondary vault recovery backup in `SharedPreferences`.
- **Zero Decrypted Leaks**: Transient video player files are automatically swept on startup and deleted immediately upon disposal.

### 🗄️ Multi-Cloud & Local Storage Engine
- **Google Drive v3**: Native integration with direct authorized streaming (`alt=media`) and prefix filtering.
- **S3-Compatible Cloud**: Full AWS Signature Version 4 (AWS4-HMAC-SHA256) support for AWS, Cloudflare R2, Backblaze B2, and MinIO.
- **WebDAV**: Seamless integration with Nextcloud, ownCloud, TrueNAS, and Synology NAS systems.
- **Local Storage**: 100% offline mode with fast in-memory indexed path resolution.
- **P2P Mesh Storage**: Peer-to-peer blob resolution over WebRTC data channels via WebSocket signaling.
- **Exponential Backoff Retries**: Automatic retry handling for transient network issues on idempotent operations.

### 🕰️ Smart Flashback Engine
- **"1 Year Ago Today"**: Relive what happened on this exact calendar day in years past.
- **"Last Month's Album"**: A retrospective highlight reel of memories captured during the previous month.
- **"A Passing Memory"**: Ephemeral weekly highlights from the past 7 days.
- **Concurrent Processing**: Parallel album evaluations for instant loading.

### 📸 High-Performance Media Feed
- **True Page-by-Page Decryption**: Only decrypts the visible page slice on demand rather than loading entire libraries into memory.
- **Dual LRU Byte-Budget Caches**: 50MB media cache and 20MB thumbnail cache with cross-session persistence.
- **Full-Screen Media Viewer**: Pinch-to-zoom photo viewer and hardware-accelerated video playback with Chewie controls.

---

# 🏗️ Architecture & Security Model

```mermaid
graph TD
    subgraph Client [Flutter Mobile App (Client-Side E2EE)]
        UI[UI: Feed, Albums, Media Viewer, Profile]
        Repo[EncryptedMemoryRepository]
        Crypto[CryptoCore (libsodium)]
        KeyStore[KeyStore & BIP39 Recovery]
        LRU[ByteBudgetLruCache (Media & Thumbs)]
    end

    subgraph Storage [Polymorphic Storage Layer]
        Drive[Google Drive Provider]
        S3[S3-Compatible Provider]
        WebDAV[WebDAV Provider]
        Local[Local Storage Provider]
        Mesh[P2P Mesh Provider]
    end

    subgraph Backends [Supported Backends]
        GDrive[(Google Drive v3)]
        Cloud[(AWS S3 / Cloudflare R2 / MinIO)]
        NAS[(Nextcloud / Synology WebDAV)]
        Disk[(Device File System)]
        Relay[(WebRTC Signaling Relay)]
    end

    UI --> Repo
    Repo --> Crypto
    Repo --> KeyStore
    Repo --> LRU
    Repo --> Storage

    Drive --> GDrive
    S3 --> Cloud
    WebDAV --> NAS
    Local --> Disk
    Mesh --> Relay
```

---

# 📂 Project Structure

```text
Kioku
│
├── flutter_mobile/
│   ├── android/
│   │   ├── app/
│   │   │   ├── build.gradle.kts     # Kotlin DSL with release signing & R8 configuration
│   │   │   ├── proguard-rules.pro   # Proguard keep rules for Flutter, libsodium & Play Core
│   │   │   └── src/main/res/xml/    # Android Network Security Config (strict HTTPS policy)
│   │   └── key.properties.example   # Template for release signing keystore configuration
│   ├── ios/                         # iOS project with privacy permission strings
│   ├── lib/
│   │   ├── core/                    # libsodium crypto, storage providers, ByteBudgetLRU, retry
│   │   ├── features/
│   │   │   ├── auth/                # Sign-in, guest mode, 24-word recovery phrase screen
│   │   │   ├── feed/                # Day-grouped timeline feed & encrypted memory repository
│   │   │   ├── flashbacks/          # Concurrently bucketed time-travel memory views
│   │   │   ├── media_viewer/        # Zero-leak video player and photo viewer
│   │   │   ├── profile/             # Multi-cloud storage setup & friend code profile
│   │   │   └── upload/              # Image compression, envelope encryption & upload
│   │   ├── shared/widgets/          # Washi tape, clay card, hanko stamp, bottom nav bar
│   │   ├── app_router.dart          # GoRouter navigation schema
│   │   └── main.dart                # App bootstrap & key store initialization
│   ├── test/                        # 44 unit & widget tests covering E2EE, storage, UI
│   └── pubspec.yaml                 # Dependencies and assets
│
├── backend/
│   ├── routes/                      # API routes (health, media, flashbacks)
│   ├── services/                    # Drive & storage services
│   ├── middleware/                  # Security headers & rate limiting
│   ├── __tests__/                   # Jest test suites (auth, signaling, flashbacks)
│   └── server.js                    # Express application & WebSocket signaling relay
│
├── releases/                        # Standalone release APKs & SHA-256 checksums
│   ├── kioku-v2.0-release.apk
│   └── README.md
├── assets/
├── start.py                         # Unified orchestrator (test, build, emulator, run)
└── README.md
```

---

# 🚀 Getting Started

## Prerequisites

- Flutter 3.22+
- Dart 3.x
- Node.js 18+
- Python 3.9+
- Android Studio with Android SDK & Emulator

## Option 1: Unified CLI Orchestrator (`start.py`)

The root `start.py` script automates environment checks, SDK detection, port forwarding, emulator boot, APK builds, and testing:

```bash
# Start development environment: runs backend, boots emulator, installs & launches app
python start.py

# Run all test suites (Node.js Jest + Flutter Unit/Widget tests)
python start.py --test

# Build optimized debug APK
python start.py --build-apk

# Build production-ready release APK (with R8 minification and Proguard rules)
python start.py --build-apk --release

# Run app in release mode on emulator/device
python start.py --release

# Skip emulator startup (for physical device or desktop testing)
python start.py --no-emulator
```

---

## Option 2: Manual Setup

### Backend

```bash
cd backend
npm install
cp .env.example .env
npm start
```

Runs at:
```text
http://localhost:4000
```

### Flutter

```bash
cd flutter_mobile
flutter pub get
flutter test
flutter run
```

---

# ☁ Google Drive & Cloud Storage Setup

Kioku can run entirely offline or connect directly to your preferred cloud:

1. **Google Drive**: Create a Google Cloud project, enable the **Google Drive API**, add the `https://www.googleapis.com/auth/drive.file` scope, and create an Android OAuth client ID.
2. **S3 Storage**: Enter your Endpoint, Bucket name, Region, Access Key ID, and Secret Access Key in Settings > Storage Setup.
3. **WebDAV**: Enter your Server URL, Username, and Password (compatible with Nextcloud and Synology).

---

# 🧪 Testing & Verification

```bash
# Run all mobile test suites (44 tests covering crypto, storage, providers, UI)
cd flutter_mobile
flutter test

# Run static analysis (0 errors, 0 warnings)
flutter analyze --no-fatal-infos

# Run backend Jest test suites
cd ../backend
npm test
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
