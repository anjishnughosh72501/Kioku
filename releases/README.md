# Kioku Releases

This directory contains standalone release builds for Kioku.

## Current Release: v2.0.0

| File | Platform | Architecture | Size | SHA-256 Checksum |
| :--- | :--- | :--- | :--- | :--- |
| **[`kioku-v2.0-release.apk`](kioku-v2.0-release.apk)** | Android 5.0+ (API 21+) | Universal (`arm64-v8a`, `armeabi-v7a`, `x86_64`) | 61.7 MB | `4BD2AAA07FF7B0CEF5519812F7FAA934FE73DA1CA69951B6AC90C1A0B9519E98` |
| **[`kioku-release.apk`](kioku-release.apk)** | Android 5.0+ (API 21+) | Universal (`arm64-v8a`, `armeabi-v7a`, `x86_64`) | 61.7 MB | `4BD2AAA07FF7B0CEF5519812F7FAA934FE73DA1CA69951B6AC90C1A0B9519E98` |

---

## 📲 Installation Instructions

### Option 1: Direct Device Install (Phone)
1. Download `kioku-v2.0-release.apk` (or `kioku-release.apk`) directly to your Android device.
2. Open the downloaded file from your browser's downloads or file manager.
3. If prompted, enable **"Install unknown apps"** for your browser or file manager in Android Settings.
4. Tap **Install** and launch Kioku.

### Option 2: Via ADB (Command Line)
Connect your Android device with USB debugging enabled (or start an emulator) and run:
```bash
adb install -r releases/kioku-v2.0-release.apk
```

---

## 📋 Release Highlights (v2.0.0)

### 🛡️ Zero-Knowledge End-to-End Encryption (E2EE)
- **libsodium Cryptographic Engine**: Industrial-grade `XChaCha20-Poly1305` chunked streaming encryption for media and `crypto_secretbox` for metadata.
- **Three-Tier Key Hierarchy**: MasterKey in hardware-backed keystore, per-album CollectionKeys, and per-media FileKeys.
- **BIP39 24-Word Recovery Phrase**: Standard mnemonic key recovery with 60s clipboard auto-clear and secondary vault recovery backup in `SharedPreferences`.
- **Zero Decrypted Leaks**: Transient video player files are automatically swept on startup and deleted immediately upon player disposal.

### 🗄️ Multi-Cloud & Local Storage Engine
- **Google Drive v3**: Native integration with direct authorized streaming (`alt=media`) and prefix filtering.
- **S3-Compatible Cloud**: Full AWS Signature Version 4 (AWS4-HMAC-SHA256) support for AWS, Cloudflare R2, Backblaze B2, and MinIO.
- **WebDAV**: Seamless integration with Nextcloud, ownCloud, TrueNAS, and Synology NAS systems.
- **Local Storage**: 100% offline mode with fast in-memory indexed path resolution.
- **P2P Mesh Storage**: Peer-to-peer blob resolution over WebRTC data channels via WebSocket signaling.
- **Exponential Backoff Retries**: Automatic retry handling for transient network issues on idempotent operations.

### ⚡ Performance & Polish
- **True Page-by-Page Decryption**: Only decrypts the visible page slice on demand rather than loading entire libraries into memory.
- **Dual LRU Byte-Budget Caches**: 50MB media cache and 20MB thumbnail cache with cross-session persistence.
- **Android R8 Minification**: Proguard rules configured with tree-shaken font assets and full obfuscation.
- **Strict Network Security Config**: HTTPS enforcement with local NAS loopback exceptions.
- **Automated Verification**: Comprehensive test coverage with 44/44 unit, widget, and integration tests passing.

---

## 📜 Previous Releases

<details>
<summary><b>v1.0.0</b> (2026-09-10)</summary>

- Initial preview release with Japanese stationery aesthetic, offline local storage, and Google Drive sync.
</details>
