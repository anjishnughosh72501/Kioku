<div align="center">

<img src="assets/kiokulogo.jpg" alt="Kioku Logo" width="180" style="border-radius: 36px; box-shadow: 0 10px 30px rgba(0,0,0,0.15);" />

# Kioku · 記憶
### *A warm, zero-knowledge private memory album and time capsule for close friend groups and couples.*

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![E2EE](https://img.shields.io/badge/Security-libsodium_E2EE-2e7d32?style=for-the-badge&logo=shield)](https://libsodium.gitbook.io/)
[![Node.js](https://img.shields.io/badge/Node.js-18+-339933?style=for-the-badge&logo=node.js&logoColor=white)](https://nodejs.org)
[![Riverpod](https://img.shields.io/badge/State-Riverpod_2.6-blueviolet?style=for-the-badge)](https://riverpod.dev)
[![License](https://img.shields.io/badge/License-MIT-amber?style=for-the-badge)](LICENSE)
[![Download APK](https://img.shields.io/badge/Download-APK_v2.0.0-E06D53?style=for-the-badge&logo=android&logoColor=white)](releases/kioku-v2.0-release.apk)

<p align="center">
  <a href="releases/kioku-v2.0-release.apk"><b>👉 Download Android APK (v2.0.0)</b></a> · 
  <a href="releases/README.md">Release Notes & Checksums</a>
</p>

</div>

---

## 📖 Overview

**Kioku** (記憶, Japanese for *"memory"*) is a cozy, tactile memory-keeping application crafted specifically for small circles—couples, best friends, and family. Rather than broadcasting life onto algorithmic social media feeds, Kioku turns moments into intimate digital scrapbooks reminiscent of handcrafted Japanese stationery.

Your photos and videos stay strictly yours. Kioku is built from the ground up with a **zero-knowledge, end-to-end encrypted (E2EE), local-first architecture**:
- **Zero-Knowledge Privacy**: All photos, videos, and metadata are encrypted client-side using **libsodium** before ever leaving your device. No cloud provider or server can inspect your memories.
- **User-Owned Storage Backends**: Store your encrypted envelopes where you choose—your personal **Google Drive**, **S3-compatible bucket** (AWS S3, Cloudflare R2, MinIO), **WebDAV server** (Nextcloud, Synology), **local on-device storage**, or via **P2P Mesh WebRTC**.
- **Tactile Japanese Stationery**: Warm cream papers, washi tapes, hanko stamps, and soft claymorphic interactions.

---

## ✨ Key Features

### 🌸 Japanese Stationery Aesthetic
- **Washi Tape & Hanko Stamps**: Organic visual accents with Japanese motifs and authentic ink textures.
- **Claymorphic UI**: Soft, tactile cards with gentle debossed and elevated clay shadows.
- **Curated Themes**:
  - ☕ **Coffee Light**: Cream paper, warm sepia ink, toasted latte tones.
  - 🌲 **Forest Dark**: Deep moss, charcoal slate, warm amber embers.

### 🛡️ Zero-Knowledge End-to-End Encryption (E2EE)
- **libsodium Cryptographic Engine**: Industrial-grade `XChaCha20-Poly1305` chunked streaming encryption for media and `crypto_secretbox` for metadata.
- **Three-Tier Key Hierarchy**:
  - **Master Key**: Generated on device and held securely in hardware-backed keystores (`flutter_secure_storage`).
  - **Collection Keys**: Unique per-album keys wrapped by the Master Key or device public keys for sharing.
  - **File Keys**: Ephemeral 256-bit keys minted per photo/video and wrapped inside the `.enc` envelope.
- **BIP39 24-Word Recovery Phrase**: Standard mnemonic key recovery with automatic clipboard protection and dual vault loss guards.
- **Zero Decrypted Leaks**: Transient video player files are automatically swept and securely deleted upon disposal.

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

## 🏗️ Architecture & Security Model

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

## 📁 Repository Structure

```
Kioku/
├── assets/                          # Shared branding assets (e.g. Kioku logo)
│   └── kiokulogo.jpg
├── backend/                         # Node.js companion backend & WebRTC relay
│   ├── __tests__/                   # Jest test suites (auth, signaling, flashbacks)
│   ├── middleware/                  # Security headers, rate limiting, and auth
│   ├── routes/                      # API routes (health, media, flashbacks)
│   ├── server.js                    # Express application & WebSocket signaling relay
│   └── package.json                 # Backend dependencies & test scripts
├── flutter_mobile/                  # Flutter mobile application
│   ├── android/
│   │   ├── app/
│   │   │   ├── build.gradle.kts     # Kotlin DSL with release signing & R8 configuration
│   │   │   ├── proguard-rules.pro   # Proguard keep rules for Flutter, libsodium & Play Core
│   │   │   └── src/main/res/xml/    # Android Network Security Config (strict HTTPS policy)
│   │   └── key.properties.example   # Template for release signing keystore configuration
│   ├── ios/                         # iOS project with privacy permission strings
│   ├── lib/
│   │   ├── core/
│   │   │   ├── crypto/              # libsodium core, envelope parser, BIP39 keystore
│   │   │   ├── drive/               # Google Drive API v3 wrapper
│   │   │   ├── models/              # Clean Architecture domain models (Memory, Album)
│   │   │   ├── storage/             # Polymorphic storage providers (Drive, S3, WebDAV, Local, Mesh)
│   │   │   ├── utils/               # Shared ByteBudgetLruCache, retryAsync utility
│   │   │   └── theme/               # Fraunces typography, Japanese palette & clay tokens
│   │   ├── features/
│   │   │   ├── auth/                # Sign-in, guest mode, 24-word recovery phrase screen
│   │   │   ├── feed/                # Day-grouped timeline feed & encrypted memory repository
│   │   │   ├── flashbacks/          # Concurrently bucketed time-travel memory views
│   │   │   ├── media_viewer/        # Zero-leak video player and photo viewer
│   │   │   ├── profile/             # Multi-cloud storage setup & friend code profile
│   │   │   └── upload/              # Image compression, envelope encryption & upload
│   │   └── main.dart                # Application bootstrap & key store initialization
│   ├── test/                        # 44 unit & widget tests covering E2EE, storage, UI
│   └── pubspec.yaml                 # Dependencies and assets
├── start.py                         # Unified orchestrator (test, build, emulator, run)
└── README.md                        # Documentation
```

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.22+ recommended)
- [Node.js](https://nodejs.org/) (v18 or newer)
- [Python](https://www.python.org/) 3.9+ (for the `start.py` orchestrator)
- [Android Studio](https://developer.android.com/studio) with an Android SDK and Emulator (e.g. `Pixel_7_API_35`)

---

### Option 1: Unified CLI Orchestrator (`start.py`)

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

### Option 2: Manual Setup

#### 1. Companion Backend
```bash
cd backend
npm install
npm test      # Verify backend test suites
npm start     # Starts on http://localhost:4000
```

#### 2. Flutter Mobile
```bash
cd flutter_mobile
flutter pub get

# Run test suite
flutter test

# Run app on connected device / emulator
flutter run

# Build release APK
flutter build apk --release
```

---

## 🔑 Security & Production Signing

### 1. Release Keystore Setup
To produce signed release APKs or App Bundles for distribution:
1. Copy the example template:
   ```bash
   cp flutter_mobile/android/key.properties.example flutter_mobile/android/key.properties
   ```
2. Generate your upload keystore:
   ```bash
   keytool -genkey -v -keystore flutter_mobile/android/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
3. Update `key.properties` with your passwords and file path.

*(During local development, Gradle automatically falls back to debug signing when `key.properties` is absent.)*

### 2. OAuth & Custom Backend Configuration
- **OAuth Client ID**: Injected at build time via `--dart-define=OAUTH_CLIENT_ID=...` or defaults to the bundled development client ID.
- **Network Security**: Strict cleartext HTTP restrictions are enforced via `network_security_config.xml`. Remote traffic must use HTTPS; cleartext is restricted to `localhost`, `10.0.2.2`, and `127.0.0.1` for local NAS development.

---

## 🧪 Testing & Verification

Kioku maintains rigorous test discipline across both client and server:

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

## 📄 License

This project is licensed under the [MIT License](LICENSE).
